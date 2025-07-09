/**
 * Landing as a Service - Chat Interface
 * Handles user interaction and API communication for both injection and company landing flows
 */

/**
 * Global variable to track the current polling operation
 */
let currentPollingOperation = null;

/**
 * Utility function to safely add a message to the chat
 * @param {string} text - The text to display
 * @param {string} sender - The sender type: 'user' or 'bot'
 * @param {boolean} isError - Whether this is an error message
 */
function addMessage(text, sender = 'bot', isError = false) {
    const chatbox = document.getElementById('chatbox');
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${sender}`;
    
    if (isError) {
        messageDiv.classList.add('error');
    }
    
    messageDiv.innerHTML = text;
    chatbox.appendChild(messageDiv);
    chatbox.scrollTop = chatbox.scrollHeight;
}

/**
 * Show a user message
 * @param {string} text - The text to display
 */
function showUserMessage(text) {
    addMessage(text, 'user');
}

/**
 * Show a bot message
 * @param {string} text - The text to display
 * @param {boolean} isLink - Whether this contains a link
 */
function showBotMessage(text, isLink = false) {
    addMessage(text, 'bot', false);
}

/**
 * Show an error message
 * @param {string} text - The error text to display
 */
function showErrorMessage(text) {
    addMessage(`❌ <strong>Error:</strong> ${text}`, 'bot', true);
}

/**
 * Validate if a string is a valid URL
 * @param {string} url - The URL to validate
 * @returns {boolean} - Whether the URL is valid
 */
function isValidUrl(url) {
    try {
        const urlObj = new URL(url);
        return urlObj.protocol === 'http:' || urlObj.protocol === 'https:';
    } catch (e) {
        return false;
    }
}

/**
 * Sanitize input text for display
 * @param {string} input - The input to sanitize
 * @returns {string} - Sanitized input
 */
function sanitizeInput(input) {
    return input.replace(/[<>&"']/g, (char) => {
        const entities = { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' };
        return entities[char];
    });
}

/**
 * Get the selected flow type from the UI
 * @returns {string} - The selected flow type
 */
function getSelectedFlowType() {
    const injectionRadio = document.getElementById('injection-mode');
    const companyLandingRadio = document.getElementById('company-landing-mode');
    
    if (injectionRadio && injectionRadio.checked) {
        return 'injection';
    } else if (companyLandingRadio && companyLandingRadio.checked) {
        return 'company_landing';
    }
    
    return 'injection'; // default
}

/**
 * Update UI based on selected flow type
 * @param {string} flowType - The selected flow type
 */
function updateUIForFlowType(flowType) {
    const promptLabel = document.querySelector('label[for="prompt"]');
    const promptInput = document.getElementById('prompt');
    const submitButton = document.getElementById('submit-button');
    
    if (flowType === 'company_landing') {
        if (promptLabel) promptLabel.textContent = 'Additional Instructions (Optional):';
        if (promptInput) promptInput.placeholder = 'e.g., Focus on enterprise solutions, include pricing section...';
        if (submitButton) submitButton.textContent = 'Create Company Landing';
    } else {
        if (promptLabel) promptLabel.textContent = 'Industry/Purpose:';
        if (promptInput) promptInput.placeholder = 'e.g., Tech startup, E-commerce, Healthcare...';
        if (submitButton) submitButton.textContent = 'Generate Landing Page';
    }
}

/**
 * Get progress message based on flow type and step
 * @param {string} flowType - The flow type
 * @param {number} step - The current step
 * @param {string} message - The message from the API
 * @returns {string} - Formatted progress message
 */
function getProgressMessage(flowType, step, message) {
    if (flowType === 'company_landing') {
        switch (step) {
            case 1:
                return '🔍 Analyzing website and extracting company information...';
            case 2:
                return '🔗 Creating final landing page...';
            default:
                return `⏳ ${message}`;
        }
    } else {
        // Injection flow
        switch (step) {
            case 1:
                return '📥 Fetching and analyzing target website...';
            case 2:
                return '🎨 Generating landing page content...';
            case 3:
                return '🔗 Creating final landing page...';
            default:
                return `⏳ ${message}`;
        }
    }
}

/**
 * Poll for job status until completion
 * @param {string} jobId - The job ID to poll
 * @param {string} statusUrl - The URL to check job status
 * @param {string} flowType - The flow type for progress messages
 */
async function pollJobStatus(jobId, statusUrl, flowType) {
    const maxAttempts = 60; // 5 minutes with 5-second intervals
    let attempts = 0;
    
    // Store the current polling operation
    const pollingOperation = { cancelled: false };
    currentPollingOperation = pollingOperation;
    
    while (attempts < maxAttempts && !pollingOperation.cancelled) {
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
            
            // Check if this polling operation was cancelled
            if (pollingOperation.cancelled) {
                return;
            }
            
            switch (statusData.status) {
                case 'completed':
                    if (statusData.data && statusData.data.htmlUrl) {
                        let completionMessage = `✅ <strong>Landing page generated successfully!</strong><br/>`;
                        
                        // Add flow-specific completion details
                        if (flowType === 'company_landing') {
                            const companyName = statusData.data.company_name || 'Unknown';
                            const industry = statusData.data.industry || 'Unknown';
                            completionMessage += `<em>Company: ${companyName} | Industry: ${industry}</em><br/>`;
                        }
                        
                        completionMessage += `<a href="${statusData.data.htmlUrl}" target="_blank" rel="noopener noreferrer">🔗 Open Generated Landing Page</a>`;
                        
                        addMessage(completionMessage);
                        
                        // Embed the result in an iframe
                        addMessage(
                            `<iframe src="${statusData.data.htmlUrl}" style="width:100%;height:400px;border:1px solid #ccc;border-radius:8px;" title="Generated Landing Page"></iframe>`
                        );
                    } else {
                        showErrorMessage('Job completed but no landing page URL received');
                    }
                    
                    // Clear the current polling operation
                    if (currentPollingOperation === pollingOperation) {
                        currentPollingOperation = null;
                    }
                    return;
                
                case 'failed':
                    showErrorMessage(statusData.error || 'Job failed with unknown error');
                    
                    // Clear the current polling operation
                    if (currentPollingOperation === pollingOperation) {
                        currentPollingOperation = null;
                    }
                    return;
                
                case 'processing':
                    // Update progress message
                    const step = statusData.data?.step || 0;
                    const message = statusData.data?.message || 'Processing...';
                    
                    const progressText = getProgressMessage(flowType, step, message);
                    
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
                    
                    // Clear the current polling operation
                    if (currentPollingOperation === pollingOperation) {
                        currentPollingOperation = null;
                    }
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
                
                // Clear the current polling operation
                if (currentPollingOperation === pollingOperation) {
                    currentPollingOperation = null;
                }
                return;
            }
            
            // Wait 2 seconds before retry (faster retry)
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }
    
    if (!pollingOperation.cancelled) {
        showErrorMessage('Timeout waiting for job completion. Please try again.');
    }
    
    // Clear the current polling operation
    if (currentPollingOperation === pollingOperation) {
        currentPollingOperation = null;
    }
}

/**
 * Send request to the API backend
 * @param {string} sourceUrl - The source website URL
 * @param {string} prompt - The user's prompt/industry description
 * @param {string} flowType - The flow type ('injection' or 'company_landing')
 */
async function sendRequest(sourceUrl, prompt, flowType) {
    // Cancel any existing polling operation
    if (currentPollingOperation) {
        currentPollingOperation.cancelled = true;
        currentPollingOperation = null;
    }
    
    // Validate inputs
    if (!isValidUrl(sourceUrl)) {
        showErrorMessage('Please enter a valid URL (must start with http:// or https://)');
        return;
    }
    
    // Sanitize inputs
    const sanitizedUrl = sanitizeInput(sourceUrl);
    const sanitizedPrompt = sanitizeInput(prompt);
    
    // Show user's request
    let userMessage = `<b>You:</b> `;
    if (flowType === 'company_landing') {
        userMessage += `Create company landing page for <em>${sanitizedUrl}</em>`;
        if (prompt) {
            userMessage += ` with additional instructions: <strong>${sanitizedPrompt}</strong>`;
        }
    } else {
        userMessage += `Generate landing page for <strong>${sanitizedPrompt}</strong> based on <em>${sanitizedUrl}</em>`;
    }
    
    addMessage(userMessage, 'user');
    
    // Show loading message
    addMessage('🚀 Submitting your request...');
    
    try {
        // Prepare request payload
        const payload = {
            source_url: sourceUrl,
            flow_type: flowType
        };
        
        // Add prompt only if provided (required for injection, optional for company_landing)
        if (prompt) {
            payload.prompt = prompt;
        }
        
        // Make API request to submit job
        const response = await fetch(config.apiEndpoint + '/chat', {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify(payload)
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
            
            const processingMessage = flowType === 'company_landing' 
                ? '⏳ Analyzing your website and creating a custom landing page... This may take up to 2 minutes.'
                : '⏳ Processing your request... This may take up to 2 minutes.';
            
            addMessage(processingMessage);
            
            // Start polling for status
            const statusUrl = config.apiEndpoint + '/status';
            await pollJobStatus(data.job_id, statusUrl, flowType);
            
        } else if (data.error) {
            showErrorMessage(data.error);
        } else {
            showErrorMessage('Unexpected response format from server');
            console.error('Unexpected response:', data);
        }
        
    } catch (error) {
        console.error('Request failed:', error);
        
        if (error.name === 'TypeError' && error.message.includes('fetch')) {
            showErrorMessage('Network error. Please check your connection and try again.');
        } else {
            showErrorMessage(error.message || 'An unexpected error occurred');
        }
    }
}

/**
 * Handle form submission
 */
function handleFormSubmit() {
    const form = document.getElementById('landing-form');
    const sourceUrl = document.getElementById('source-url').value.trim();
    const prompt = document.getElementById('prompt').value.trim();
    const flowType = getSelectedFlowType();
    
    // Validate required fields
    if (!sourceUrl) {
        showErrorMessage('Please enter a source URL');
        return;
    }
    
    if (flowType === 'injection' && !prompt) {
        showErrorMessage('Please enter an industry/purpose for the injection flow');
        return;
    }
    
    // Send the request
    sendRequest(sourceUrl, prompt, flowType);
    
    // Clear form
    form.reset();
    
    // Update UI for the default flow type
    updateUIForFlowType('injection');
}

/**
 * Initialize the chat application
 */
function initializeChat() {
    console.log('Chat initialized');
    
    // Add event listeners for flow type changes
    const injectionRadio = document.getElementById('injection-mode');
    const companyLandingRadio = document.getElementById('company-landing-mode');
    
    if (injectionRadio) {
        injectionRadio.addEventListener('change', () => {
            if (injectionRadio.checked) {
                updateUIForFlowType('injection');
            }
        });
    }
    
    if (companyLandingRadio) {
        companyLandingRadio.addEventListener('change', () => {
            if (companyLandingRadio.checked) {
                updateUIForFlowType('company_landing');
            }
        });
    }
    
    // Add event listener for the Generate Landing Page button
    const sendButton = document.getElementById('send-chat');
    if (sendButton) {
        sendButton.addEventListener('click', handleFormSubmit);
    }
    
    // Set initial UI state
    updateUIForFlowType('injection');
    
    // Show welcome message
    addMessage('👋 Welcome to Landing Page Generator! Choose your generation mode and enter a URL to get started.');
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', initializeChat); 