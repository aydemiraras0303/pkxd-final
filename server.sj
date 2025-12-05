const express = require("express");
const app = express();
const server = require("http").createServer(app);
const io = require("socket.io")(server);

app.use(express.static(__dirname + "/"));

let players = {};
let allFurniture = {};
let taskList = [
    { name: "Topla 5 elma", reward: 100 },
    { name: "Evini temizle", reward: 50 },
    { name: "Arkadaşını ziyaret et", reward: 75 },
    { name: "Mini oyunu kazan", reward: 150 }
];

io.on("connection", socket => {
    console.log("Player connected:", socket.id);

    players[socket.id] = {
        id: socket.id,
        x: 400,
        y: 300,
        name: "Player" + socket.id.substring(0,4),
        money: 0,
        tasks: taskList.map(t=>({...t, progress:0})),
        skin: null
    };

    socket.emit("currentPlayers", players);
    socket.broadcast.emit("newPlayer", players[socket.id]);

    socket.on("move", data => {
        if(players[socket.id]){
            players[socket.id].x = data.x;
            players[socket.id].y = data.y;
            io.emit("playerMoved", players);
        }
    });

    socket.on("completeTask", index => {
        if(players[socket.id] && players[socket.id].tasks[index]){
            players[socket.id].money += players[socket.id].tasks[index].reward;
            players[socket.id].tasks[index].progress = 100;
            socket.emit("updateTasks", players[socket.id].tasks);
            io.emit("playerUpdated", players[socket.id]);
        }
    });

    socket.on("changeSkin", skin => {
        if(players[socket.id]){
            players[socket.id].skin = skin;
            io.emit("skinChanged",{id:socket.id, skin});
        }
    });

    // Furniture
    socket.on("saveFurniture", data => {
        allFurniture[socket.id] = data;
        io.emit("updateFurniture",{playerId: socket.id, furniture: data});
    });
    socket.on("requestFurniture", ()=>{ if(allFurniture[socket.id]) socket.emit("loadFurniture", allFurniture[socket.id]); });
    socket.on("requestAllFurniture", ()=>{ socket.emit("loadAllFurniture", allFurniture); });

    // Chat
    socket.on("chatMessage", msg => { io.emit("chatMessage", {id:socket.id, name:players[socket.id].name, msg}); });

    socket.on("disconnect", () => {
        console.log("Player disconnected:", socket.id);
        delete players[socket.id];
        io.emit("playerDisconnected", socket.id);
    });
});

server.listen(3000,()=>console.log("Server running at http://localhost:3000"));
