FROM node:16.14-buster-slim

COPY . /app
RUN chmod +x /app/mkdocs_pdf.sh

RUN /app/mkdocs_pdf.sh --prepare --tmp /app/build -l sc
RUN /app/mkdocs_pdf.sh --prepare --tmp /app/build -l hc
RUN /app/mkdocs_pdf.sh --prepare --tmp /app/build -l tc
RUN /app/mkdocs_pdf.sh --prepare --tmp /app/build -l jp
RUN /app/mkdocs_pdf.sh --prepare --tmp /app/build -l kr

# clean
RUN rm -rf /var/lib/apt/lists/*

ENTRYPOINT ['/app/mkdocs_pdf.sh', '-l', 'sc', '--tmp', '/app/build']
