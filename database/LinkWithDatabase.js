import mysql from 'mysql2';

const db = mysql.createConnection({
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'root',
    database: 'GPS_db',
});

db.connect((err) => {
    if (err) console.error("Erreur connexion MySQL:", err.message);
    else console.log("Connecté à la base de données MySQL !");
});

