(function(){
    let idToken = null;

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
                document.getElementById('form').style.display = 'block';
            },
            onFailure: function(err) {
                alert(err.message || JSON.stringify(err));
            }
        });
    });

    document.getElementById('submit').addEventListener('click', function() {
        const payload = {
            imagen: document.getElementById('imagen').value,
            titulo: document.getElementById('titulo').value,
            subtitulo: document.getElementById('subtitulo').value,
            beneficios: document.getElementById('beneficios').value,
            cta: document.getElementById('cta').value
        };
        fetch(config.apiEndpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': idToken
            },
            body: JSON.stringify(payload)
        })
        .then(r => r.json())
        .then(data => {
            const url = data.url ? data.url : config.cloudfrontUrl + '/' + data.path;
            window.location.href = url;
        })
        .catch(err => alert('Error: ' + err));
    });
})();
