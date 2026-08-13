# ============================================================
# EPUB Fordító – Frontend multi-stage Docker build
#
# 1. szakasz: Node.js környezet a React app build-eléséhez
# 2. szakasz: Nginx, ami a kész dist/ mappát szolgálja ki
#             és az API kéréseket a backend konténerre proxizza.
#
# Ennek köszönhetően a végfelhasználónak NEM kell Node.js-t
# telepítenie a gazdagépre – a Docker mindent megépít.
# ============================================================

# ---- 1. SZAKASZ: BUILD ----
FROM node:20-alpine AS builder

WORKDIR /app

# Függőségek telepítése (külön a cache kihasználáshoz)
COPY package.json package-lock.json ./
RUN npm ci

# Forráskód másolása és production build
COPY . .
RUN npm run build

# ---- 2. SZAKASZ: SZOLGÁLTATÁS ----
FROM nginx:alpine

# SPA nginx konfiguráció (SPA fallback + API proxy)
COPY nginx.conf /etc/nginx/nginx.conf

# A build output másolása a builder szakaszból
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

# Nginx az előtérben fut (ne lépjen ki a konténer)
CMD ["nginx", "-g", "daemon off;"]