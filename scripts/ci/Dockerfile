FROM node@sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32
RUN apk add --no-cache python3 zip ffmpeg
USER node
WORKDIR /workspace
CMD ["sh", "-c", "npm ci --ignore-scripts && npm run package"]
