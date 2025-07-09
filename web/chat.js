/**
 * Landing as a Service - Chat Interface
 * Handles user interaction and API communication
 */

// Chat state
let chatHistory = [];

/**
 * Add a message to the chat interface
 * @param {string} text - The message text (can include HTML)
 * @param {string} sender - Message sender ('bot' or 'user')
 * @param {boolean} isError - Whether this is an error message
 */
function addMessage(text, sender = 'bot', isError = false) {
    const chatbox = document.getElementById('chatbox');
    
    // Create message container
    const msgDiv = document.createElement('div');
    msgDiv.className = 'msg' + (sender === 'user' ? ' user' : '') + (isError ? ' error' : '');
    
    // Create message bubble
    const bubble = document.createElement('div');
    bubble.className = 'bubble';
    bubble.innerHTML = text;
    
    msgDiv.appendChild(bubble);
    chatbox.appendChild(msgDiv);
    
    // Auto-scroll to bottom
    chatbox.scrollTo({ 
        top: chatbox.scrollHeight, 
        behavior: 'smooth' 
    });
}

/**
 * Display a user message in the chat
 * @param {string} text - The user's message
 */
function showUserMessage(text) {
    addMessage(`<b>You:</b> ${text}`, 'user');
}

/**
 * Display a bot message, with special handling for links
 * @param {string} text - The bot's message
 * @param {boolean} isLink - Whether the message is a link
 */
function showBotMessage(text, isLink = false) {
    if (isLink || (typeof text === 'string' && text.startsWith('http'))) {
        addMessage(
            `<b>Landing Page:</b> <a href="${text}" target="_blank" rel="noopener noreferrer">${text}</a>`, 
            'bot'
        );
    } else {
        addMessage(text, 'bot');
    }
}

/**
 * Display an error message in the chat
 * @param {string} text - The error message
 */
function showErrorMessage(text) {
    addMessage(`<b>Error:</b> ${text}`, 'bot', true);
}

/**
 * Validate URL format
 * @param {string} url - URL to validate
 * @returns {boolean} Whether the URL is valid
 */
function isValidUrl(url) {
    try {
        new URL(url);
        return url.startsWith('http://') || url.startsWith('https://');
    } catch {
        return false;
    }
}

/**
 * Sanitize user input to prevent XSS
 * @param {string} input - User input to sanitize
 * @returns {string} Sanitized input
 */
function sanitizeInput(input) {
    const div = document.createElement('div');
    div.textContent = input;
    return div.innerHTML;
}

/**
 * Poll for job status until completion
 * @param {string} jobId - The job ID to poll
 * @param {string} statusUrl - The URL to check job status
 */
async function pollJobStatus(jobId, statusUrl) {
    const maxAttempts = 60; // 5 minutes with 5-second intervals
    let attempts = 0;
    
    while (attempts < maxAttempts) {
        try {
            const response = await fetch(`${statusUrl}/${jobId}`, {
                method: 'GET',
                headers: { 
                    'Accept': 'application/json'
                }
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const statusData = await response.json();
            console.log('Status check:', statusData);
            
            switch (statusData.status) {
                case 'completed':
                    if (statusData.data && statusData.data.htmlUrl) {
                        addMessage(
                            `✅ <strong>Landing page generated successfully!</strong><br/>
                            <a href="${statusData.data.htmlUrl}" target="_blank" rel="noopener noreferrer">🔗 Open Generated Landing Page</a>`
                        );
                        
                        // Embed the result in an iframe
                        addMessage(
                            `<iframe src="${statusData.data.htmlUrl}" style="width:100%;height:400px;border:1px solid #ccc;border-radius:8px;" title="Generated Landing Page"></iframe>`
                        );
                    } else {
                        showErrorMessage('Job completed but no landing page URL received');
                    }
                    return;
                
                case 'failed':
                    showErrorMessage(statusData.error || 'Job failed with unknown error');
                    return;
                
                case 'processing':
                    // Update progress message
                    const step = statusData.data?.step || 0;
                    const message = statusData.data?.message || 'Processing...';
                    
                    let progressText = '';
                    if (step === 1) {
                        progressText = '📥 Fetching source website...';
                    } else if (step === 2) {
                        progressText = '🎨 Generating AI landing content...';
                    } else if (step === 3) {
                        progressText = '🔗 Creating final landing page...';
                    } else {
                        progressText = `⏳ ${message}`;
                    }
                    
                    // Only add message if it's different from the last one
                    const chatbox = document.getElementById('chatbox');
                    const lastMessage = chatbox.lastElementChild;
                    if (!lastMessage || !lastMessage.textContent.includes(progressText)) {
                        addMessage(progressText);
                    }
                    break;
                
                case 'queued':
                    addMessage('📋 Job queued for processing...');
                    break;
                
                case 'not_found':
                    showErrorMessage('Job not found. Please try again.');
                    return;
                
                default:
                    console.log(`Unknown status: ${statusData.status}`);
                    break;
            }
            
            // Wait 2 seconds before next poll (faster feedback)
            await new Promise(resolve => setTimeout(resolve, 2000));
            attempts++;
            
        } catch (error) {
            console.error('Status polling error:', error);
            attempts++;
            
            if (attempts >= maxAttempts) {
                showErrorMessage('Timeout waiting for job completion. Please try again.');
                return;
            }
            
            // Wait 2 seconds before retry (faster retry)
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }
    
    showErrorMessage('Timeout waiting for job completion. Please try again.');
}

/**
 * Send request to the API backend
 * @param {string} sourceUrl - The source website URL
 * @param {string} prompt - The user's prompt/industry description
 */
async function sendRequest(sourceUrl, prompt) {
    // Validate inputs
    if (!isValidUrl(sourceUrl)) {
        showErrorMessage('Please enter a valid URL (must start with http:// or https://)');
        return;
    }
    
    // Sanitize inputs
    const sanitizedUrl = sanitizeInput(sourceUrl);
    const sanitizedPrompt = sanitizeInput(prompt);
    
    // Show user's request
    addMessage(
        `<b>You:</b> Generate landing page for <strong>${sanitizedPrompt}</strong> based on <em>${sanitizedUrl}</em>`, 
        'user'
    );
    
    // Show loading message
    addMessage('🚀 Submitting your request...');
    
    try {
        // Make API request to submit job
        const response = await fetch(config.apiEndpoint + '/chat', {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify({ 
                source_url: sourceUrl, 
                prompt: prompt 
            })
        });
        
        // Check if response is ok
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        console.log('Job submission response:', data);
        
        // Handle successful job submission
        if (data.job_id && data.status === 'queued') {
            addMessage(`✅ Job submitted successfully! ID: ${data.job_id}`);
            addMessage('⏳ Processing your request... This may take up to 2 minutes.');
            
            // Start polling for status
            const statusUrl = config.apiEndpoint + '/status';
            await pollJobStatus(data.job_id, statusUrl);
            
        } else if (data.error) {
            showErrorMessage(data.error);
        } else {
            showErrorMessage('Unexpected response format from server');
            console.error('Unexpected response:', data);
        }
        
    } catch (error) {
        console.error('Request failed:', error);
        
        if (error.name === 'TypeError' && error.message.includes('fetch')) {
            showErrorMessage('Network error: Unable to connect to the server. Please check your internet connection.');
        } else if (error.message.includes('HTTP 429')) {
            showErrorMessage('Too many requests. Please wait a moment and try again.');
        } else if (error.message.includes('HTTP 500')) {
            showErrorMessage('Server error. Please try again later.');
        } else if (error.message.includes('HTTP 503')) {
            showErrorMessage('Service temporarily unavailable. This may be due to high load or maintenance.');
        } else {
            showErrorMessage(`Request failed: ${error.message}`);
        }
    }
}

/**
 * Handle form submission
 */
function handleFormSubmit() {
    const sourceUrl = document.getElementById('source-url').value.trim();
    const prompt = document.getElementById('prompt').value.trim();
    
    // Validate required fields
    if (!sourceUrl) {
        showErrorMessage('Please enter a source website URL');
        document.getElementById('source-url').focus();
        return;
    }
    
    if (!prompt) {
        showErrorMessage('Please enter a prompt or industry description');
        document.getElementById('prompt').focus();
        return;
    }
    
    // Clear form fields
    document.getElementById('source-url').value = '';
    document.getElementById('prompt').value = '';
    
    // Send the request
    sendRequest(sourceUrl, prompt);
}

/**
 * Initialize the chat interface
 */
function initializeChat() {
    // Add welcome message
    addMessage(
        `👋 <strong>Welcome to Landing as a Service!</strong><br/>
        Enter a website URL and describe your industry to generate a custom landing page.`
    );
    
    // Add event listeners
    const sendButton = document.getElementById('send-chat');
    if (sendButton) {
        sendButton.addEventListener('click', handleFormSubmit);
    }
    
    // Handle Enter key in input fields
    const inputs = ['source-url', 'prompt'];
    inputs.forEach(inputId => {
        const input = document.getElementById(inputId);
        if (input) {
            input.addEventListener('keypress', function(event) {
                if (event.key === 'Enter') {
                    handleFormSubmit();
                }
            });
        }
    });
    
    // Focus on first input
    const firstInput = document.getElementById('source-url');
    if (firstInput) {
        firstInput.focus();
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', initializeChat); 