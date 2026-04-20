FROM alpine:latest

RUN apk add --no-cache icecast ffmpeg bash curl

COPY radio.sh /radio.sh
COPY songs.json /songs.json
COPY admin.html /admin.html
COPY audio /audio

RUN chmod +x /radio.sh

EXPOSE 8000 8080

CMD ["/radio.sh"]
