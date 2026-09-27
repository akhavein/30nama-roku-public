FROM node@sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32
WORKDIR /app
COPY --chmod=644 server.mjs ./
USER 65532:65532
ENV NODE_ENV=production
CMD ["node", "/app/server.mjs"]
