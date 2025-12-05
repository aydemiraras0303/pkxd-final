const socket = io();
const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

let players = {};
let me = {
    x: 400,
    y: 300,
    speed: 4,
    money: 0,
    tasks: [],
    skin: null,
    inMiniGame: false
};

let keys = {};
document.addEventListener("keydown", e => keys[e.key] = true);
document.addEventListener("keyup", e => keys[e.key] = false);

// Jump
let isJumping = false;
let jumpSpeed = 0;
const gravity = 0.5;
const jumpSound = new Audio("jump.wav");

document.addEventListener("keydown", e => {
    if (e.key === "w" || e.key === "W") {
        if (!isJumping) {
            isJumping = true;
            jumpSpeed = -10;
            jumpSound.play();
        }
    }
});

// Chat
const chatInput = document.getElementById("chatInput");
const messagesDiv = document.getElementById("messages");
chatInput.addEventListener("keydown", e => {
    if (e.key === "Enter" && chatInput.value.trim() !== "") {
        socket.emit("chatMessage", chatInput.value);
        chatInput.value = "";
    }
});
socket.on("chatMessage", data => {
    const div = document.createElement("div");
    div.textContent = data.name + ": " + data.msg;
    messagesDiv.appendChild(div);
    messagesDiv.scrollTop = messagesDiv.scrollHeight;
});

// UI update
function updateMoneyUI() {
    document.getElementById("money").textContent = players[socket.id] ? players[socket.id].money : 0;
}

function updateTaskUI() {
    const taskDiv = document.getElementById("task");
    taskDiv.innerHTML = "";
    if (me.tasks) me.tasks.forEach((t, i) => {
        const tElem = document.createElement("div");
        tElem.textContent = t.name + " (" + t.progress + "%)";
        if (t.progress < 100) {
            const btn = document.createElement("button");
            btn.textContent = "Tamamla";
            btn.onclick = () => socket.emit("completeTask", i);
            tElem.appendChild(btn);
        }
        taskDiv.appendChild(tElem);
    });
}

// Player events
socket.on("currentPlayers", data => {
    players = data;
    updateMoneyUI();
    updateTaskUI();
});
socket.on("newPlayer", data => { players[data.id] = data; });
socket.on("playerMoved", data => { players = data; });
socket.on("playerDisconnected", id => { delete players[id]; });
socket.on("playerUpdated", data => { players[data.id] = data; updateMoneyUI(); updateTaskUI(); });
socket.on("skinChanged", data => { if (players[data.id]) players[data.id].skin = data.skin; });

// Furniture
socket.on("loadFurniture", data => { for (let id in data) { const f = document.getElementById(id); if (f) { f.style.left = data[id].left; f.style.top = data[id].top; } } });
socket.on("loadAllFurniture", data => { for (let pid in data) { if (pid === socket.id) continue; for (let fid in data[pid]) { let f = document.createElement("div"); f.className = "furniture"; f.id = pid + "_" + fid; f.style.width = "50px"; f.style.height = "50px"; f.style.background = "#ccc"; f.style.position = "absolute"; f.style.left = data[pid][fid].left; f.style.top = data[pid][fid].top; f.style.cursor = "grab"; document.getElementById("furnitureArea").appendChild(f); } } });
socket.on("updateFurniture", data => { for (let fid in data.furniture) { let f = document.getElementById(data.playerId + "_" + fid); if (!f) { f = document.createElement("div"); f.className = "furniture"; f.id = data.playerId + "_" + fid; f.style.position = "absolute"; f.style.width = "50px"; f.style.height = "50px"; f.style.background = "#ccc"; f.style.cursor = "grab"; document.getElementById("furnitureArea").appendChild(f); } f.style.left = data.furniture[fid].left; f.style.top = data.furniture[fid].top; } });

// Furniture drag
let selectedFurniture = null, offsetX = 0, offsetY = 0;
document.querySelectorAll(".furniture").forEach(f => {
    f.addEventListener("mousedown", e => {
        selectedFurniture = f;
        offsetX = e.offsetX;
        offsetY = e.offsetY;
        f.style.cursor = "grabbing";
    });
});
document.addEventListener("mousemove", e => {
    if (selectedFurniture) {
        const parent = selectedFurniture.parentElement.getBoundingClientRect();
        selectedFurniture.style.left = (e.clientX - parent.left - offsetX) + "px";
        selectedFurniture.style.top = (e.clientY - parent.top - offsetY) + "px";
    }
});
document.addEventListener("mouseup", () => { if (selectedFurniture) { selectedFurniture.style.cursor = "grab"; selectedFurniture = null; } });

// Save furniture
document.getElementById("saveFurniture").addEventListener("click", () => {
    const furnitures = {};
    document.querySelectorAll(".furniture").forEach(f => { furnitures[f.id] = { left: f.style.left, top: f.style.top }; });
    socket.emit("saveFurniture", furnitures);
    alert("Mobilyalar kaydedildi!");
});

// House open/close
const houseUI = document.getElementById("houseUI");
const exitHouse = document.getElementById("exitHouse");
let inHouse = false;
document.addEventListener("keydown", e => {
    if (e.key === "E" && !inHouse) {
        if (me.x > 350 && me.x < 450 && me.y > 250 && me.y < 350) {
            inHouse = true;
            houseUI.style.display = "block";
            socket.emit("requestFurniture");
            socket.emit("requestAllFurniture");
        }
    }
});
exitHouse.addEventListener("click", () => { inHouse = false; houseUI.style.display = "none"; });

// Skin market
const skinUI = document.getElementById("skinUI");
document.getElementById("openSkin").addEventListener("click", () => { skinUI.style.display = skinUI.style.display === "none" ? "block" : "none"; });
document.querySelectorAll(".skin").forEach(btn => {
    btn.addEventListener("click", () => {
        const skin = btn.dataset.skin;
        const cost = parseInt(btn.dataset.cost || "50");
        if (players[socket.id].money >= cost) {
            players[socket.id].money -= cost;
            players[socket.id].skin = skin;
            socket.emit("changeSkin", skin);
            updateMoneyUI();
        } else alert("Paran yetmiyor!");
    });
});

// Mini game
function checkMiniGame() {
    if (me.x > 600 && me.x < 650 && me.y > 100 && me.y < 150 && !me.inMiniGame) {
        me.inMiniGame = true;
        alert("Mini oyun başladı: topu yakala!");
        let caught = confirm("Topu yakaladın mı? (Tamam -> Evet, İptal -> Hayır)");
        if (caught) { me.money += 100; updateMoneyUI(); }
        me.inMiniGame = false;
    }
}

// Game loop
function update() {
    if (keys["ArrowUp"]) me.y -= me.speed;
    if (keys["ArrowDown"]) me.y += me.speed;
    if (keys["ArrowLeft"]) me.x -= me.speed;
    if (keys["ArrowRight"]) me.x += me.speed;

    if (isJumping) { me.y += jumpSpeed; jumpSpeed += gravity; if (me.y >= 300) { me.y = 300; isJumping = false; } }

    socket.emit("move", { x: me.x, y: me.y });
    checkMiniGame();
}

function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Harita
    ctx.fillStyle = "#6c3"; ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#ffea"; ctx.fillRect(350, 250, 100, 100);
    ctx.fillStyle = "#999"; ctx.fillRect(0, 550, 800, 50);

    for (let id in players) {
        let p = players[id];
        let color = "#fff"; 
        if (p.skin === "red") color = "#f00";
        else if (p.skin === "blue") color = "#00f";
        else if (id === socket.id) color = "#0f0";

        ctx.fillStyle = color;
        let height = (id === socket.id && isJumping) ? 30 : 40;
        ctx.fillRect(p.x, p.y, 40, height);
        ctx.fillStyle = "#000";
        ctx.fillText(p.name, p.x, p.y - 10);
    }
}

function gameLoop() { update(); draw(); requestAnimationFrame(gameLoop); }
gameLoop();
