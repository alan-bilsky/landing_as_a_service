// Minimal polyfill for Web Streams API (required for Node.js 16 compatibility with undici)
if (typeof ReadableStream === 'undefined') {
  // Minimal ReadableStream polyfill - just enough to make undici load
  global.ReadableStream = class ReadableStream {
    constructor(underlyingSource = {}) {
      this._underlyingSource = underlyingSource;
    }
    getReader() {
      return {
        read: () => Promise.resolve({ done: true, value: undefined }),
        cancel: () => Promise.resolve(),
        releaseLock: () => {}
      };
    }
    cancel() {
      return Promise.resolve();
    }
    tee() {
      return [this, this];
    }
  };
}

if (typeof WritableStream === 'undefined') {
  global.WritableStream = class WritableStream {
    constructor(underlyingSink = {}) {
      this._underlyingSink = underlyingSink;
    }
    getWriter() {
      return {
        write: (chunk) => Promise.resolve(),
        close: () => Promise.resolve(),
        abort: () => Promise.resolve(),
        releaseLock: () => {}
      };
    }
    abort() {
      return Promise.resolve();
    }
  };
}

if (typeof TransformStream === 'undefined') {
  global.TransformStream = class TransformStream {
    constructor(transformer = {}) {
      this.readable = new ReadableStream();
      this.writable = new WritableStream();
    }
  };
}

const chromium = require('chrome-aws-lambda');
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const https = require('https');
const http = require('http');
const zlib = require('zlib');
const cheerio = require('cheerio');

// TODO: Import AWS SDK and Bedrock client when ready
// const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');

const s3 = new AWS.S3();

// CORS headers for API Gateway
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type,Authorization",
  "Access-Control-Allow-Methods": "OPTIONS,POST"
};

function validateUrl(url) {
  try {
    const parsed = new URL(url);
    
    // Only allow HTTP and HTTPS protocols
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return false;
    }
    
    const hostname = parsed.hostname.toLowerCase();
    
    // Reject localhost variations
    if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1') {
      return false;
    }
    
    // Reject private IP ranges (RFC 1918)
    // 10.0.0.0/8 (10.0.0.0 to 10.255.255.255)
    if (hostname.startsWith('10.')) {
      return false;
    }
    
    // 172.16.0.0/12 (172.16.0.0 to 172.31.255.255)
    if (hostname.startsWith('172.')) {
      const octets = hostname.split('.');
      if (octets.length === 4 && octets[0] === '172') {
        const secondOctet = parseInt(octets[1]);
        if (secondOctet >= 16 && secondOctet <= 31) {
          return false;
        }
      }
    }
    
    // 192.168.0.0/16 (192.168.0.0 to 192.168.255.255)
    if (hostname.startsWith('192.168.')) {
      return false;
    }
    
    // Reject link-local addresses (169.254.0.0/16)
    if (hostname.startsWith('169.254.')) {
      return false;
    }
    
    // Reject IPv6 private ranges
    if (hostname.startsWith('fc00:') || hostname.startsWith('fd00:') || hostname.startsWith('fe80:')) {
      return false;
    }
    
    // Reject other internal/reserved addresses
    if (hostname.startsWith('0.') || hostname.startsWith('127.') || hostname.startsWith('224.') || hostname.startsWith('240.')) {
      return false;
    }
    
    return true;
  } catch {
    return false;
  }
}

function stripQueryParams(url) {
  try {
    const parsed = new URL(url);
    // Remove query parameters and fragments as specified in security rules
    parsed.search = '';
    parsed.hash = '';
    return parsed.href;
  } catch {
    return url;
  }
}

async function httpGetWithRetry(url, options = {}, maxRetries = 3) {
  let lastError;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`fetch_site: Attempt ${attempt}/${maxRetries} for URL: ${url}`);
      const result = await httpGet(url, { 
        ...options, 
        attempt // Pass attempt number to adjust strategy
      });
      
      // Check for successful response or redirect
      if (result.status >= 200 && result.status < 400) {
        console.log(`fetch_site: Success on attempt ${attempt}, status: ${result.status}, size: ${result.data.length} bytes`);
        
        // Handle redirects (3xx status codes)
        if (result.status >= 300 && result.status < 400) {
          const location = result.headers.location;
          if (location) {
            console.log(`fetch_site: Following redirect to: ${location}`);
            // Follow the redirect
            return await httpGet(location, options);
          }
        }
        
        return result;
      } else if (result.status === 403) {
        // Special handling for 403 Forbidden
        console.log(`fetch_site: Got 403 Forbidden on attempt ${attempt}, trying alternative strategy...`);
        throw new Error(`HTTP 403: Access Forbidden - Site may be blocking automated requests`);
      } else {
        throw new Error(`HTTP ${result.status}: ${result.statusText || 'Unknown error'}`);
      }
    } catch (error) {
      lastError = error;
      console.log(`fetch_site: Attempt ${attempt} failed: ${error.message}`);
      
      // Don't retry on final attempt
      if (attempt === maxRetries) {
        break;
      }
      
      // For 403 errors, wait longer and try different strategy
      const is403 = error.message.includes('403');
      const delay = is403 ? Math.pow(2, attempt) * 2000 : Math.pow(2, attempt - 1) * 1000;
      
      console.log(`fetch_site: Waiting ${delay}ms before retry...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  
  throw new Error(`Failed after ${maxRetries} attempts. Last error: ${lastError.message}`);
}

function httpGet(url, options = {}) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https:') ? https : http;
    const attempt = options.attempt || 1;
    
    // Enhanced headers to simulate different browsers and avoid detection
    const userAgents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    ];
    
    // Cycle through different user agents on retries
    const userAgent = userAgents[(attempt - 1) % userAgents.length];
    
    // More sophisticated headers that vary by attempt
    const baseHeaders = {
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-User': '?1',
      'Cache-Control': 'max-age=0',
      'sec-ch-ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"'
    };
    
    // Add attempt-specific headers to avoid patterns
    if (attempt > 1) {
      // Add some randomization on retries
      const referers = [
        'https://www.google.com/',
        'https://www.bing.com/',
        'https://duckduckgo.com/',
        'https://www.yahoo.com/',
        'https://www.baidu.com/'
      ];
      baseHeaders['Referer'] = referers[Math.floor(Math.random() * referers.length)];
    }
    
    if (attempt > 2) {
      // More aggressive headers on final attempts
      baseHeaders['X-Forwarded-For'] = '1.1.1.1'; // Cloudflare DNS
      baseHeaders['X-Real-IP'] = '8.8.8.8'; // Google DNS
      baseHeaders['CF-Connecting-IP'] = '1.1.1.1';
    }
    
    const headers = { ...baseHeaders, ...(options.headers || {}) };
    
    // Increase timeout on retries
    const timeout = (options.timeout || 20000) + (attempt - 1) * 5000;
    
    const req = client.get(url, { 
      timeout: timeout,
      headers: headers
    }, (res) => {
      let data = [];
      
      // Handle gzip/deflate/brotli decompression
      let decompressStream = res;
      const contentEncoding = res.headers['content-encoding'];
      
      if (contentEncoding === 'gzip') {
        decompressStream = res.pipe(zlib.createGunzip());
      } else if (contentEncoding === 'deflate') {
        decompressStream = res.pipe(zlib.createInflate());
      } else if (contentEncoding === 'br') {
        try {
          decompressStream = res.pipe(zlib.createBrotliDecompress());
        } catch (error) {
          console.log(`fetch_site: Brotli decompression failed, falling back to raw data: ${error.message}`);
          decompressStream = res;
        }
      }
      
      // Add debug logging for compression
      console.log(`fetch_site: Content-Encoding header: ${contentEncoding}`);
      console.log(`fetch_site: Response status: ${res.statusCode}`);
      console.log(`fetch_site: User-Agent used: ${userAgent}`);
      
      decompressStream.on('data', chunk => {
        data.push(chunk);
      });
      
      decompressStream.on('end', () => {
        const buffer = Buffer.concat(data);
        console.log(`fetch_site: Final buffer size: ${buffer.length}`);
        console.log(`fetch_site: First 100 bytes of buffer: ${buffer.slice(0, 100).toString('hex')}`);
        
        resolve({
          data: buffer,
          headers: res.headers,
          status: res.statusCode,
          statusText: res.statusMessage
        });
      });
      decompressStream.on('error', reject);
    });
    
    req.on('error', (error) => {
      console.log(`fetch_site: Request error: ${error.message}`);
      reject(error);
    });
    
    req.on('timeout', () => {
      console.log(`fetch_site: Request timeout after ${timeout}ms`);
      reject(new Error(`Request timeout after ${timeout}ms`));
    });
  });
}

async function downloadAndUploadToS3(url, s3Bucket, s3Prefix) {
  let s3Key = `${s3Prefix}/${Date.now()}-${Math.random().toString(36).slice(2)}`;
  try {
    const response = await httpGetWithRetry(url, {
      timeout: 20000  // Enhanced timeout, headers handled automatically
    });
    const ext = url.split('.').pop().split('?')[0].split('#')[0];
    s3Key = `${s3Prefix}/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
    await s3.putObject({
      Bucket: s3Bucket,
      Key: s3Key,
      Body: response.data,
      ContentType: response.headers['content-type'] || 'application/octet-stream',
    }).promise();
    
    // Return CloudFront URL instead of direct S3 URL since S3 bucket has public access blocked
    // The CloudFront domain should be provided via environment variable
    const cloudfrontDomain = process.env.CLOUDFRONT_DOMAIN;
    if (cloudfrontDomain) {
      return `https://${cloudfrontDomain}/${s3Key}`;
    } else {
      // Fallback to S3 URL (but will be 403 Forbidden due to public access block)
      console.warn('CLOUDFRONT_DOMAIN not set, falling back to S3 URL which may be inaccessible');
      return `https://${s3Bucket}.s3.amazonaws.com/${s3Key}`;
    }
  } catch (err) {
    console.error(`Failed to download/upload asset, S3 key: ${s3Key}`, err.message || String(err));
    return url; // fallback to original if failed
  }
}

function absolutizeUrl(url, baseUrl) {
  try {
    return new URL(url, baseUrl).href;
  } catch {
    return url;
  }
}

async function processHtmlAndAssets(html, baseUrl, s3Bucket, s3Prefix) {
  // Ensure HTML is properly decoded as UTF-8 string before processing
  let htmlString = html;
  if (Buffer.isBuffer(html)) {
    htmlString = html.toString('utf-8');
  } else if (typeof html !== 'string') {
    htmlString = String(html);
  }
  
  // Load HTML with cheerio, ensuring proper UTF-8 handling
  const $ = cheerio.load(htmlString, {
    decodeEntities: false,  // Prevent double-encoding of entities
    normalizeWhitespace: false,  // Preserve original whitespace
    xmlMode: false,  // HTML mode, not XML
    lowerCaseAttributeNames: false  // Preserve original case
  });
  
  const urlMap = {};
  
  // Helper to process and rewrite a single asset URL
  async function processAsset(selector, attr) {
    const elements = $(selector);
    for (let i = 0; i < elements.length; i++) {
      const el = elements[i];
      const origUrl = $(el).attr(attr);
      if (origUrl && !origUrl.startsWith('data:')) {
        const absUrl = absolutizeUrl(origUrl, baseUrl);
        if (!urlMap[absUrl]) {
          urlMap[absUrl] = await downloadAndUploadToS3(absUrl, s3Bucket, s3Prefix);
        }
        $(el).attr(attr, urlMap[absUrl]);
      }
    }
  }
  
  // Process images, CSS, JS, favicon, etc.
  await processAsset('img', 'src');
  await processAsset('link[rel="stylesheet"]', 'href');
  await processAsset('link[rel~="icon"]', 'href');
  await processAsset('script[src]', 'src');
  
  // Inline and rewrite CSS url(...) references
  const cssLinks = $('link[rel="stylesheet"]');
  for (let i = 0; i < cssLinks.length; i++) {
    const link = cssLinks[i];
    const cssUrl = $(link).attr('href');
    if (cssUrl && !cssUrl.startsWith('data:')) {
      const absCssUrl = absolutizeUrl(cssUrl, baseUrl);
      try {
        const cssResp = await httpGetWithRetry(absCssUrl, { timeout: 5000 });
        let cssText = cssResp.data.toString('utf-8');
        // Find all url(...) in CSS
        const urlRegex = /url\((['"]?)([^'"\)]+)\1\)/g;
        let match;
        while ((match = urlRegex.exec(cssText)) !== null) {
          const assetUrl = match[2];
          if (!assetUrl.startsWith('data:')) {
            const absAssetUrl = absolutizeUrl(assetUrl, absCssUrl);
            if (!urlMap[absAssetUrl]) {
              urlMap[absAssetUrl] = await downloadAndUploadToS3(absAssetUrl, s3Bucket, s3Prefix);
            }
            cssText = cssText.replace(assetUrl, urlMap[absAssetUrl]);
          }
        }
        // Inline the CSS
        const styleTag = `<style>${cssText}</style>`;
        $(link).replaceWith(styleTag);
      } catch (err) {
        console.error('Failed to inline CSS for URL:', err.message || String(err));
      }
    }
  }
  
  // Return the properly encoded HTML
  return { html: $.html(), urlMap };
}

// Helper to find the hero section: largest <section> or first after navbar
function findHeroSection($) {
  let largestSection = null;
  let maxArea = 0;
  $('section').each((i, el) => {
    const area = ($(el).width() || 0) * ($(el).height() || 0);
    if (area > maxArea) {
      maxArea = area;
      largestSection = el;
    }
  });
  if (largestSection) return largestSection;
  const nav = $('nav, header').first();
  if (nav.length > 0) {
    let next = nav.next();
    while (next.length > 0 && next[0].type !== 'tag') next = next.next();
    if (next.length > 0) return next[0];
  }
  return $('section').first()[0];
}

function getHeroSelectors($, hero) {
  const hero$ = cheerio.load($.html(hero));
  let headlineSel = null, subheadlineSel = null, ctaSel = null;
  if (hero$('h1').length > 0) headlineSel = 'h1';
  else if (hero$('h2').length > 0) headlineSel = 'h2';
  if (hero$('h2').length > 1) subheadlineSel = 'h2';
  else if (hero$('h3').length > 0) subheadlineSel = 'h3';
  if (hero$('button').length > 0) ctaSel = 'button';
  else if (hero$('a.btn, a.button, a.cta').length > 0) ctaSel = 'a.btn, a.button, a.cta';
  return {
    heroSelector: $(hero).attr('id') ? `#${$(hero).attr('id')}` : 'section',
    headlineSel,
    subheadlineSel,
    ctaSel
  };
}

async function processHeroSection(html, $) {
  const hero = findHeroSection($);
  if (!hero) return { html, mapping: null };
  const hero$ = cheerio.load($.html(hero));
  // Find headline, subheadline, CTA button
  let headlineSel = null, subheadlineSel = null, ctaSel = null;
  // Headline: first h1 or h2
  if (hero$('h1').length > 0) {
    headlineSel = 'h1';
    hero$('h1').first().text('{{TITLE}}');
  } else if (hero$('h2').length > 0) {
    headlineSel = 'h2';
    hero$('h2').first().text('{{TITLE}}');
  }
  // Subheadline: first h2 or h3 after headline
  if (hero$('h2').length > 1) {
    subheadlineSel = 'h2';
    hero$('h2').eq(1).text('{{SUBTITLE}}');
  } else if (hero$('h3').length > 0) {
    subheadlineSel = 'h3';
    hero$('h3').first().text('{{SUBTITLE}}');
  }
  // CTA: first <button> or <a> with button-like class
  if (hero$('button').length > 0) {
    ctaSel = 'button';
    hero$('button').first().text('{{CTA}}');
  } else if (hero$('a.btn, a.button, a.cta').length > 0) {
    ctaSel = 'a.btn, a.button, a.cta';
    hero$('a.btn, a.button, a.cta').first().text('{{CTA}}');
  }
  // Replace the hero section in the main HTML
  $(hero).replaceWith(hero$.html());
  // Return mapping for Bedrock Lambda
  const mapping = {
    heroSelector: $(hero).attr('id') ? `#${$(hero).attr('id')}` : 'section',
    headlineSel,
    subheadlineSel,
    ctaSel
  };
  return { html: $.html(), mapping };
}

async function extractThemeInfo(page) {
  return await page.evaluate(() => {
    // CSS links (now inlined, but keep for completeness)
    const cssLinks = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).map(l => l.href);
    
    // Inline styles
    const inlineStyles = Array.from(document.querySelectorAll('style')).map(s => s.innerHTML);
    
    // Logo
    const logoTag = document.querySelector('img[alt*="logo"], img[src*="logo"]');
    const logo_url = logoTag ? logoTag.src : null;
    
    // Favicon
    const faviconTag = document.querySelector('link[rel~="icon"]');
    const favicon_url = faviconTag ? faviconTag.href : null;
    
    // Hero image (first large image in main or body)
    let hero_image_url = null;
    const mainImg = document.querySelector('main img') || document.querySelector('body img');
    if (mainImg && mainImg.width > 300 && mainImg.height > 150) hero_image_url = mainImg.src;
    
    // Colors (from computed styles)
    const bodyStyles = window.getComputedStyle(document.body);
    const color_palette = [bodyStyles.backgroundColor, bodyStyles.color];
    
    // Fonts (from computed styles)
    const font_family = bodyStyles.fontFamily;
    
    // Layout hints
    const layout_hints = {
      has_header: !!document.querySelector('header'),
      has_nav: !!document.querySelector('nav'),
      has_main: !!document.querySelector('main'),
      has_footer: !!document.querySelector('footer')
    };
    
    return {
      css_links: cssLinks,
      inline_styles: inlineStyles,
      logo_url,
      favicon_url,
      hero_image_url,
      color_palette,
      fonts: [font_family],
      layout_hints
    };
  });
}

async function fetchWithPuppeteerFallback(url, s3Bucket, s3Prefix) {
  console.log('fetch_site: Attempting Puppeteer fallback for URL:', url);
  
  let browser = null;
  try {
    // Enhanced launch arguments for better stealth and compatibility
    browser = await chromium.puppeteer.launch({
      args: [
        ...chromium.args,
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--disable-gpu',
        '--window-size=1920x1080',
        '--disable-web-security',
        '--disable-features=VizDisplayCompositor',
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
        '--disable-renderer-backgrounding',
        '--disable-blink-features=AutomationControlled',
        '--disable-extensions',
        '--disable-plugins',
        '--disable-default-apps',
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-infobars',
        '--disable-component-extensions-with-background-pages',
        '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      ],
      defaultViewport: { width: 1920, height: 1080 },
      executablePath: await chromium.executablePath,
      headless: chromium.headless,
    });
    
    const page = await browser.newPage();
    
    // Comprehensive stealth techniques for protected sites like DataCamp
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    
    // Set realistic extra HTTP headers
    await page.setExtraHTTPHeaders({
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Cache-Control': 'max-age=0',
      'Connection': 'keep-alive',
      'DNT': '1',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-User': '?1',
      'sec-ch-ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"'
    });
    
    // Advanced stealth techniques to avoid detection
    await page.evaluateOnNewDocument(() => {
      // Remove webdriver property
      Object.defineProperty(navigator, 'webdriver', {
        get: () => undefined,
      });
      
      // Override chrome property
      window.chrome = {
        runtime: {}
      };
      
             // Override permissions API
       const originalQuery = window.navigator.permissions.query;
       window.navigator.permissions.query = (parameters) => (
         parameters.name === 'notifications' ?
           Promise.resolve({ state: 'granted' }) :
           originalQuery(parameters)
       );
      
      // Randomize screen properties
      Object.defineProperty(screen, 'width', { get: () => 1920 });
      Object.defineProperty(screen, 'height', { get: () => 1080 });
      Object.defineProperty(screen, 'availWidth', { get: () => 1920 });
      Object.defineProperty(screen, 'availHeight', { get: () => 1040 });
      Object.defineProperty(screen, 'colorDepth', { get: () => 24 });
      Object.defineProperty(screen, 'pixelDepth', { get: () => 24 });
      
      // Override language properties
      Object.defineProperty(navigator, 'language', { get: () => 'en-US' });
      Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
      
      // Override platform
      Object.defineProperty(navigator, 'platform', { get: () => 'Win32' });
      
      // Add realistic navigator properties
      Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => 8 });
      Object.defineProperty(navigator, 'deviceMemory', { get: () => 8 });
      
      // Override plugins to make it look like a real browser
      Object.defineProperty(navigator, 'plugins', {
        get: () => [
          {
            name: 'Chrome PDF Plugin',
            filename: 'internal-pdf-viewer',
            description: 'Portable Document Format'
          }
        ]
      });
    });
    
    console.log('fetch_site: Navigating to page with enhanced Puppeteer stealth...');
    
    // Multiple navigation attempts with different strategies
    let response = null;
    let lastError = null;
    
    // Strategy 1: Direct navigation
    try {
      response = await page.goto(url, { 
        waitUntil: 'networkidle2', 
        timeout: 45000 
      });
      console.log('fetch_site: Direct navigation successful');
    } catch (error) {
      console.log('fetch_site: Direct navigation failed:', error.message);
      lastError = error;
      
      // Strategy 2: Try with different wait condition
      try {
        console.log('fetch_site: Trying navigation with domcontentloaded...');
        response = await page.goto(url, { 
          waitUntil: 'domcontentloaded', 
          timeout: 30000 
        });
        console.log('fetch_site: DOMContentLoaded navigation successful');
        
        // Wait for additional content to load
        try {
          await page.waitForTimeout(5000);
          await page.waitForSelector('body', { timeout: 10000 });
        } catch (waitError) {
          console.log('fetch_site: Additional wait failed, but continuing:', waitError.message);
        }
      } catch (secondError) {
        console.log('fetch_site: Second navigation strategy failed:', secondError.message);
        lastError = secondError;
        
        // Strategy 3: Try with just load event
        try {
          console.log('fetch_site: Trying navigation with load event...');
          response = await page.goto(url, { 
            waitUntil: 'load', 
            timeout: 20000 
          });
          console.log('fetch_site: Load event navigation successful');
          
          // Give it extra time for dynamic content
          await page.waitForTimeout(8000);
        } catch (thirdError) {
          console.log('fetch_site: All navigation strategies failed');
          throw new Error(`All Puppeteer navigation strategies failed. Last error: ${thirdError.message}`);
        }
      }
    }
    
    // Check if navigation was successful
    if (!response || !response.ok()) {
      const status = response ? response.status() : 'unknown';
      const statusText = response ? response.statusText() : 'unknown';
      throw new Error(`Puppeteer navigation failed: ${status} ${statusText}`);
    }
    
    console.log('fetch_site: Navigation successful, response status:', response.status());
    
    // Wait for the page to be fully loaded and interactive
    try {
      await page.waitForFunction('document.readyState === "complete"', { timeout: 10000 });
      console.log('fetch_site: Page ready state is complete');
    } catch (readyError) {
      console.log('fetch_site: Ready state wait failed, continuing:', readyError.message);
    }
    
    // Additional wait for dynamic content (important for sites like DataCamp)
    await page.waitForTimeout(3000);
    
    // Try to dismiss any cookie banners or overlays that might interfere
    try {
      const commonDismissSelectors = [
        '[data-test*="cookie"] button[data-test*="accept"]',
        '[id*="cookie"] button[id*="accept"]',
        '[class*="cookie"] button[class*="accept"]',
        'button[class*="accept-all"]',
        'button[id*="accept-all"]',
        '.cookie-banner button',
        '#cookie-banner button',
        '[aria-label*="Accept"]',
        '[aria-label*="Close"]'
      ];
      
      for (const selector of commonDismissSelectors) {
        try {
          const element = await page.$(selector);
          if (element) {
            await element.click();
            console.log('fetch_site: Clicked dismiss button:', selector);
            await page.waitForTimeout(1000);
            break;
          }
        } catch (clickError) {
          // Ignore click errors, continue trying other selectors
        }
      }
    } catch (dismissError) {
      console.log('fetch_site: Cookie banner dismissal failed:', dismissError.message);
    }
    
    // Get the full HTML content
    const html = await page.content();
    console.log('fetch_site: Retrieved HTML via Puppeteer, size:', html.length);
    
    // Validate that we got meaningful content
    if (html.length < 1000) {
      console.log('fetch_site: Warning - Retrieved HTML is very small, may be blocked');
    }
    
    // Check for common blocking indicators
    const blockingIndicators = [
      'blocked', 'forbidden', 'access denied', 'not authorized',
      'cloudflare', 'security check', 'captcha', 'bot detection'
    ];
    
    const htmlLower = html.toLowerCase();
    for (const indicator of blockingIndicators) {
      if (htmlLower.includes(indicator)) {
        console.log(`fetch_site: Warning - Detected potential blocking indicator: ${indicator}`);
      }
    }
    
    // Extract theme info while we have the page open
    const themeInfo = await extractThemeInfo(page);
    
    return { html, themeInfo };
    
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

exports.handler = async (event) => {
  let browser = null;
  try {
    // Parse input
    let url;
    if (event.body) {
      const body = JSON.parse(event.body);
      url = body.url || body.source_url;
    } else {
      url = event.url || event.source_url;
    }
    
    if (!url) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: "Missing URL parameter" })
      };
    }
    
    // Strip query parameters before validation and fetching as per security rules
    const cleanUrl = stripQueryParams(url);
    
    // Validate URL
    if (!validateUrl(cleanUrl)) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: "Invalid URL provided" })
      };
    }
    
    const bucket = process.env.HTML_OUTPUT_BUCKET;
    if (!bucket) {
      throw new Error('HTML_OUTPUT_BUCKET env var is required');
    }
    
    console.log('fetch_site: Processing URL (cleaned):', cleanUrl);
    console.log('fetch_site: Environment - bucket:', bucket);
    console.log('fetch_site: Available globals:', {
      ReadableStream: typeof ReadableStream,
      WritableStream: typeof WritableStream,
      TransformStream: typeof TransformStream
    });
    
    let originalHtml;
    let themeInfo;
    let usedPuppeteer = false;
    
    try {
      // First, try the regular HTTP method
      console.log('fetch_site: Attempting regular HTTP download...');
      const resp = await httpGetWithRetry(cleanUrl, { 
        timeout: 20000
      });
      console.log('fetch_site: HTTP download successful, size:', resp.data.length, 'bytes');
      originalHtml = resp.data.toString('utf-8');
      
      // For regular HTTP success, we still need to extract theme info with Puppeteer
      console.log('fetch_site: Launching Puppeteer for theme extraction...');
      browser = await chromium.puppeteer.launch({
        args: chromium.args,
        defaultViewport: chromium.defaultViewport,
        executablePath: await chromium.executablePath,
        headless: chromium.headless,
      });
      console.log('fetch_site: Puppeteer launched successfully');
      
      const page = await browser.newPage();
      console.log('fetch_site: Setting page content...');
      await page.setContent(originalHtml, { waitUntil: 'networkidle2' });
      console.log('fetch_site: Extracting theme info...');
      themeInfo = await extractThemeInfo(page);
      console.log('fetch_site: Theme info extracted');
      
    } catch (httpError) {
      console.log('fetch_site: HTTP method failed:', httpError.message);
      
      // If HTTP failed with 403 or similar, try Puppeteer fallback
      if (httpError.message.includes('403') || httpError.message.includes('Forbidden') || 
          httpError.message.includes('timeout') || httpError.message.includes('ECONNRESET')) {
        
        console.log('fetch_site: Attempting Puppeteer fallback due to:', httpError.message);
        
        try {
          const puppeteerResult = await fetchWithPuppeteerFallback(cleanUrl, bucket, 'raw');
          originalHtml = puppeteerResult.html;
          themeInfo = puppeteerResult.themeInfo;
          usedPuppeteer = true;
          console.log('fetch_site: Puppeteer fallback successful');
        } catch (puppeteerError) {
          console.error('fetch_site: Both HTTP and Puppeteer methods failed');
          console.error('fetch_site: HTTP error:', httpError.message);
          console.error('fetch_site: Puppeteer error:', puppeteerError.message);
          
          // Return a more informative error
          throw new Error(`Unable to fetch website. HTTP error: ${httpError.message}. Puppeteer fallback error: ${puppeteerError.message}. This website may have strong anti-bot protection.`);
        }
      } else {
        // Re-throw non-403 errors
        throw httpError;
      }
    }
    
    // Process HTML and all assets
    console.log('fetch_site: Processing HTML and assets...');
    const { html: rewrittenHtml, urlMap } = await processHtmlAndAssets(originalHtml, cleanUrl, bucket, 'raw');
    console.log('fetch_site: HTML processing complete, rewritten size:', rewrittenHtml.length, 'bytes');
    
    // Store the original HTML in raw/ prefix
    const htmlKey = `raw/${uuidv4()}/original.html`;
    console.log('fetch_site: Uploading original HTML to S3...');
    
    // Ensure the original HTML is properly encoded as UTF-8
    let originalHtmlToStore = originalHtml;
    if (Buffer.isBuffer(originalHtml)) {
      originalHtmlToStore = originalHtml.toString('utf-8');
    } else if (typeof originalHtml !== 'string') {
      originalHtmlToStore = String(originalHtml);
    }
    
    await s3.putObject({
      Bucket: bucket,
      Key: htmlKey,
      Body: originalHtmlToStore,
      ContentType: 'text/html; charset=utf-8',
      ContentEncoding: 'utf-8'
    }).promise();
    console.log('fetch_site: Original HTML uploaded');
    
    // Store the rewritten HTML in raw/ prefix
    const rewrittenHtmlKey = `raw/${uuidv4()}/rewritten.html`;
    console.log('fetch_site: Uploading rewritten HTML to S3...');
    
    // Ensure the rewritten HTML is properly encoded as UTF-8
    let rewrittenHtmlToStore = rewrittenHtml;
    if (Buffer.isBuffer(rewrittenHtml)) {
      rewrittenHtmlToStore = rewrittenHtml.toString('utf-8');
    } else if (typeof rewrittenHtml !== 'string') {
      rewrittenHtmlToStore = String(rewrittenHtml);
    }
    
    await s3.putObject({
      Bucket: bucket,
      Key: rewrittenHtmlKey,
      Body: rewrittenHtmlToStore,
      ContentType: 'text/html; charset=utf-8',
      ContentEncoding: 'utf-8'
    }).promise();
    console.log('fetch_site: Rewritten HTML uploaded');
    
    console.log('fetch_site: Successfully processed and stored HTML - S3 keys:', {
      original_html: htmlKey,
      rewritten_html: rewrittenHtmlKey
    });
    
    // Return theme info and S3 keys
    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        theme_info: themeInfo,
        s3_keys: {
          original_html: htmlKey,
          rewritten_html: rewrittenHtmlKey
        },
        url_map: urlMap,
        method_used: usedPuppeteer ? 'puppeteer' : 'http',
        status: "fetched"
      })
    };
    
  } catch (err) {
    console.error('fetch_site: Error occurred:', err.message || String(err));
    console.error('fetch_site: Error stack:', err.stack);
    console.error('fetch_site: Error type:', err.constructor.name);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        error: err.message || String(err),
        errorType: err.constructor.name,
        status: "error"
      })
    };
  } finally {
    if (browser !== null) {
      await browser.close();
    }
  }
}; 