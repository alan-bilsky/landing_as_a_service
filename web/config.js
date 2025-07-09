// Landing as a Service - Frontend Configuration
const config = {
    apiEndpoint: 'https://sfwwrb68gf.execute-api.us-west-2.amazonaws.com',
    maxRetries: 3,
    retryDelay: 1000,
    statusCheckInterval: 2000,
    timeout: 300000 // 5 minutes
};

// Export for module systems (if needed)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = config;
} 