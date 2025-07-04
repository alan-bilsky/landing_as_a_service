(function(){
    let idToken = null;
    let chatHistory = [];

    function addMessage(text, sender = 'bot', isError = false) {
        const chatbox = document.getElementById('chatbox');
        const msgDiv = document.createElement('div');
        msgDiv.className = 'msg' + (sender === 'user' ? ' user' : '') + (isError ? ' error' : '');
        const bubble = document.createElement('div');
        bubble.className = 'bubble';
        bubble.innerHTML = text;
        msgDiv.appendChild(bubble);
        chatbox.appendChild(msgDiv);
        chatbox.scrollTo({ top: chatbox.scrollHeight, behavior: 'smooth' });
    }

    function showUserMessage(text) {
        addMessage(`<b>You:</b> ${text}`, 'user');
    }
    function showBotMessage(text, isLink) {
        if (isLink || (typeof text === 'string' && text.startsWith('http'))) {
            addMessage(`<b>Landing Page:</b> <a href="${text}" target="_blank">${text}</a>`, 'bot');
        } else {
            addMessage(text, 'bot');
        }
    }
    function showErrorMessage(text) {
        addMessage(`<b>Error:</b> ${text}`, 'bot', true);
    }

    document.getElementById('login').addEventListener('click', function() {
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;

        const authDetails = new AmazonCognitoIdentity.AuthenticationDetails({
            Username: username,
            Password: password
        });

        const userPool = new AmazonCognitoIdentity.CognitoUserPool({
            UserPoolId: config.userPoolId,
            ClientId: config.userPoolClientId
        });

        const user = new AmazonCognitoIdentity.CognitoUser({
            Username: username,
            Pool: userPool
        });

        user.authenticateUser(authDetails, {
            onSuccess: function(result) {
                idToken = result.getIdToken().getJwtToken();
                document.getElementById('auth').style.display = 'none';
                document.getElementById('chat-container').style.display = 'block';
            },
            onFailure: function(err) {
                alert(err.message || JSON.stringify(err));
            },
            newPasswordRequired: function(userAttributes, requiredAttributes) {
                var newPassword = prompt("You must set a new password for your account:");
                user.completeNewPasswordChallenge(newPassword, {}, this);
            }
        });
    });

    document.getElementById('send-chat').addEventListener('click', function() {
        const input = document.getElementById('chat-input');
        const sourceInput = document.getElementById('source-url');
        const prompt = input.value.trim();
        const sourceUrl = sourceInput.value.trim();
        if (!prompt) return;
        showUserMessage(prompt);
        input.value = '';
        showBotMessage('Generating landing page, please wait...');
        const body = { prompt };
        if (sourceUrl) body.source_url = sourceUrl;
        fetch(config.apiEndpoint + '/chat-landing', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': localStorage.getItem('idToken') || ''
            },
            body: JSON.stringify(body)
        })
        .then(r => r.json())
        .then(data => {
            if (data.htmlUrl) {
                showBotMessage(data.htmlUrl, true);
            } else if (data.error) {
                showErrorMessage(data.error);
            } else {
                showBotMessage('Unexpected response.');
            }
        })
        .catch(err => {
            showErrorMessage('Error: ' + err);
        });
    });
})();
