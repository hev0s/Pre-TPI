import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import cors from 'cors';

const app = express();
app.use(cors());

const server = http.createServer(app);

const io = new Server(server, {
    cors: {
        origin: "http://localhost:5173",
        methods: ["GET", "POST"]
    }
});

app.get('/', (req, res) => {
    res.send('Serveur Waze API en ligne !');
});

io.on('connection', (socket) => {
    console.log(`User connected: ${socket.id}`);
});

const PORT = 3001;
server.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}!`);
});
