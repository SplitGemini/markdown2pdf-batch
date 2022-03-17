FROM node:16.14-buster-slim

RUN  apt update && apt install --no-install-recommends -y \
    ca-certificates fonts-liberation fonts-liberation2 fonts-noto-color-emoji \
    fonts-takao gconf-service libasound2 libatk-bridge2.0-0 libatk1.0-0 libc6 \
    libcairo2 libcups2 libdbus-1-3 libdrm2 libexpat1 libfontconfig1 libgbm-dev \
    libgbm1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 \
    libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 \
    libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
    libxi6 libxrandr2 libxrender1 libxshmfence1 libxss1 libxtst6 lsb-release wget \
    xdg-utils

COPY . /app
RUN cd /app && npm ci

# clean
RUN rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["node", "/app/index.js"]
