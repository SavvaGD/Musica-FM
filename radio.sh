#!/bin/bash

# Пароль берётся из переменной окружения ADMIN_PASS
if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS="musica2024"
fi

# Конфиг Icecast
cat > /etc/icecast.xml << EOF
<icecast>
    <listen-socket>
        <port>8000</port>
    </listen-socket>
    <mount>
        <mount-name>/musica.mp3</mount-name>
    </mount>
</icecast>
EOF

# Генерируем admin.html с нужным паролем
cat > /admin.html << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Musica FM — Пульт</title>
    <style>
        body {
            background: #1a1a1a;
            color: white;
            font-family: Arial;
            text-align: center;
            padding: 20px;
        }
        .panel {
            background: #2d2d2d;
            max-width: 400px;
            margin: 50px auto;
            padding: 30px;
            border-radius: 15px;
        }
        h1 { color: #ff3b3b; }
        button {
            background: #ff3b3b;
            color: white;
            border: none;
            padding: 20px 40px;
            font-size: 20px;
            border-radius: 50px;
            margin: 10px;
            cursor: pointer;
        }
        button:disabled {
            background: #666;
            cursor: not-allowed;
        }
        #status {
            padding: 20px;
            font-size: 18px;
        }
        input {
            padding: 10px;
            font-size: 16px;
            margin: 10px;
            border-radius: 5px;
            border: none;
        }
    </style>
</head>
<body>
    <div class="panel">
        <h1>🎙 MUSICA FM</h1>
        
        <div id="loginForm">
            <input type="password" id="pass" placeholder="Пароль">
            <button onclick="login()">Войти</button>
        </div>
        
        <div id="adminPanel" style="display:none">
            <div id="status">Ожидание джингла...</div>
            <button id="liveBtn" disabled onclick="startLive()">🎤 Вторгнуться в эфир</button>
            <button onclick="jingleNow()">🎵 МФМ сейчас</button>
        </div>
    </div>

    <script>
        const PASS = '${ADMIN_PASS}';
        let canLive = false;
        
        function login() {
            if (document.getElementById('pass').value === PASS) {
                document.getElementById('loginForm').style.display = 'none';
                document.getElementById('adminPanel').style.display = 'block';
                checkStatus();
                setInterval(checkStatus, 2000);
            }
        }
        
        async function checkStatus() {
            try {
                const res = await fetch('/live-status');
                const status = await res.text();
                canLive = status.includes('live_ready');
                document.getElementById('liveBtn').disabled = !canLive;
                document.getElementById('status').textContent = canLive ? 
                    '🎤 МОЖНО ВТОРГАТЬСЯ!' : '⏳ Жди "Мьюзика эфэм"...';
            } catch(e) {}
        }
        
        function jingleNow() {
            fetch('/jingle-now');
        }
        
        async function startLive() {
            document.getElementById('liveBtn').disabled = true;
            document.getElementById('status').textContent = '🔴 ПРЯМОЙ ЭФИР!';
            
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            const mediaRecorder = new MediaRecorder(stream);
            
            mediaRecorder.ondataavailable = async (e) => {
                await fetch('/live-stream', {
                    method: 'POST',
                    body: e.data
                });
            };
            
            mediaRecorder.start(1000);
            
            setTimeout(() => {
                mediaRecorder.stop();
                stream.getTracks().forEach(t => t.stop());
                document.getElementById('status').textContent = 'Эфир завершён';
            }, 60000);
        }
    </script>
</body>
</html>
EOF

# Запускаем веб-сервер для админки
while true; do
    echo -e "HTTP/1.1 200 OK\n\n$(cat /admin.html)" | nc -l -p 8080 -q 1
done &

# Запускаем Icecast
icecast -c /etc/icecast.xml &

sleep 2

# Файл для live-команд
LIVE_CMD="/tmp/live.cmd"
echo "" > $LIVE_CMD

# Основной цикл вещания
while true; do
    SONGS=$(cat /songs.json | grep -o '"[^"]*\.mp3"' | tr -d '"')
    
    for i in 1 2 3; do
        if [ -f $LIVE_CMD ] && [ "$(cat $LIVE_CMD)" = "live" ]; then
            echo "" > $LIVE_CMD
            ffmpeg -f mp3 -i tcp://0.0.0.0:9999?listen=1 -f mp3 icecast://source:hackme@localhost:8000/musica.mp3
        else
            SONG=$(echo "$SONGS" | shuf -n 1)
            ffmpeg -i "/audio/songs/$SONG" -f mp3 icecast://source:hackme@localhost:8000/musica.mp3
        fi
    done
    
    ffmpeg -i /audio/mfm.mp3 -f mp3 icecast://source:hackme@localhost:8000/musica.mp3
    
    echo "live_ready" > $LIVE_CMD
    sleep 10
    echo "" > $LIVE_CMD
done
