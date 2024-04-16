import express, { Request, Response } from 'express';
import puppeteer from 'puppeteer';

const router = express.Router();

router.get('/get-data', async (req: Request, res: Response) => {
    const pageUrl = req.query.pageUrl as string;

    if (!pageUrl) {
        return res.status(400).json({ message: 'URL is required' });
    }

    try {
        const browser = await puppeteer.launch();
        const page = await browser.newPage();
        await page.goto(pageUrl, { waitUntil: 'networkidle0' });

        // Selector for the button that reveals the phone number
        const buttonSelector = 'i[rest="user-phone"]';
        await page.waitForSelector(buttonSelector);
        await page.click(buttonSelector);

        // Selector for the element containing the phone number
        const phoneSelector = 'div.--flex-1.--pl-4.--pr-4';
        await page.waitForSelector(phoneSelector, { visible: true });

        // Using a workaround to bypass TypeScript errors
        const phoneNumber = await page.evaluate((selector: string) => {
            const element = document.querySelector(selector);
            return element ? (element as HTMLElement).innerText.trim() : '';
        }, phoneSelector);

        await browser.close();

        if (!phoneNumber) {
            return res.status(404).json({ message: 'Phone number not found' });
        }

        res.json({ phoneNumber });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Error fetching phone number' });
    }
});

export default router;
