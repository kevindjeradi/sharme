// server.ts
import express from 'express';
import cors from 'cors';
import scraperRoutes from './routes/scraper_route';

declare global {
    namespace Express {
        interface Request {
            userId?: string;
        }
    }
}

require('dotenv').config();

const app = express();
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 3003;
const APP_URL = process.env.APP_URL || '';

app.use(cors());

app.use('/api', scraperRoutes);

app.listen(PORT, '0.0.0.0', function () {
    console.log(`Server is running on ${APP_URL}${PORT}`);
}
);