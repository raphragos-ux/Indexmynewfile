#!/bin/bash
set +e

# =========================================
# SHELL DEPLOYER BY RAFAEL R.
# VMESS + VLESS + TROJAN + SHADOWSOCKS
# =========================================

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

PROJECT_ID="$(gcloud config get-value project)"
REGION="us-central1"
RAND=$(openssl rand -hex 3)
CLOUD_RUN_SERVICE_NAME="rafael-$RAND"
DOMAIN="www.google.com"
WSPATH_VMESS="/Rafael-Tv"
PASSWORD_VMESS="rafaeltv"
BUILD_DIR=$(mktemp -d)

cleanup() { rm -rf "$BUILD_DIR"; }
trap cleanup EXIT

clear
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}       SHELL DEPLOYER BY RAFAEL R.${NC}"
echo -e "${GREEN}    VMESS + VLESS + TROJAN + SS${NC}"
echo -e "${CYAN}=========================================${NC}"

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}ERROR: No Google Cloud project set.${NC}"
    echo "Run first: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "${GREEN}Enabling required APIs...${NC}"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com

echo -e "${GREEN}Select Billing Mode:${NC}"
echo "1) Request-based"
echo "2) Instance-based"
read -p "Choice: " BILLING_CHOICE
[ "$BILLING_CHOICE" = "2" ] && BILLING_MODE="instance" || BILLING_MODE="request"

echo -e "${GREEN}Select Memory (recommended: 4Gi):${NC}"
read -p "Memory [512Mi/1Gi/2Gi/4Gi/8Gi/16Gi/32Gi]: " MEMORY
MEMORY=${MEMORY:-4Gi}

echo -e "${GREEN}Select vCPU (recommended: 4):${NC}"
read -p "vCPU [1/2/4/6/8]: " CPU
CPU=${CPU:-4}

CONCURRENCY="1000"
TIMEOUT="3600"
SPECIAL_MODE="false"
[ "$MEMORY" = "4Gi" ] && [ "$CPU" = "4" ] && SPECIAL_MODE="true"

read -p "Min Instances [default=0]: " MIN_INST
MIN_INST=${MIN_INST:-0}
[[ ! "$MIN_INST" =~ ^[01]$ ]] && MIN_INST=0

if [ "$SPECIAL_MODE" = "true" ]; then
    read -p "Max Instances [1-4, default=1]: " MAX_INST
    MAX_INST=${MAX_INST:-1}
    [[ ! "$MAX_INST" =~ ^[1-4]$ ]] && MAX_INST=1
else
    read -p "Max Instances [0-2, default=0]: " MAX_INST
    MAX_INST=${MAX_INST:-0}
    [[ ! "$MAX_INST" =~ ^[0-2]$ ]] && MAX_INST=0
fi

mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR" || exit 1

# Ilagay dito ang laman ng config.json, nginx.conf, entrypoint.sh, Dockerfile
cat > config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "vmess-ws",
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [ { "id": "$PASSWORD_VMESS", "alterId": 0, "security": "auto" } ] },
      "sniffing": { "enabled": true, "metadataOnly": false },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "$WSPATH_VMESS" } }
    },
    {
      "tag": "trojan-ws",
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": { "clients": [ { "password": "rafaeltv" } ] },
      "sniffing": { "enabled": true, "metadataOnly": false },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan-rafael?ed=2180" } }
    },
    {
      "tag": "vless-ws",
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [ { "id": "15f7e8ea-7b56-45d4-93af-31f3c592fdf1", "level": 0, "email": "vless-rafael" } ], "decryption": "none" },
      "sniffing": { "enabled": true, "metadataOnly": false },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless-rafael?ed=2180" } }
    },
    {
      "tag": "ss-httpupgrade",
      "port": 11004,
      "listen": "127.0.0.1",
      "protocol": "shadowsocks",
      "settings": { "method": "chacha20-ietf-poly1305", "password": "rafaeltv", "network": "tcp,udp" },
      "sniffing": { "enabled": true, "metadataOnly": false },
      "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/httpupgrade-rafael?ed=2180" } }
    }
  ],
  "outbounds": [ { "protocol": "freedom", "tag": "direct" } ]
}
EOF

cat > nginx.conf <<EOF
worker_processes auto;
worker_rlimit_nofile 200000;
events { worker_connections 65535; multi_accept on; }
http {
    sendfile on; tcp_nopush on; tcp_nodelay on;
    keepalive_timeout 65; keepalive_requests 100000;
    client_max_body_size 0;
    proxy_connect_timeout 300; proxy_send_timeout 86400; proxy_read_timeout 86400;
    proxy_buffering off; proxy_request_buffering off;
    server_tokens off;
    gzip on; gzip_comp_level 5; gzip_types text/plain text/css application/json application/javascript;

    map \$request_uri \$backend_host { default $DOMAIN; }
    map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }

    server {
        listen 8080; http2 on;
        location / {
            proxy_ssl_server_name on; proxy_ssl_protocols TLSv1.2 TLSv1.3;
            proxy_pass https://\$backend_host;
            proxy_set_header Host \$backend_host;
            proxy_set_header Referer https://www.google.com/;
            proxy_set_header Origin https://www.cloudflare.com/;
            proxy_set_header Connection ""; proxy_http_version 1.1;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
        location $WSPATH_VMESS {
            proxy_pass http://127.0.0.1:10000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$host;
            proxy_read_timeout 86400;
        }
        location /trojan-rafael {
            proxy_pass http://127.0.0.1:10001;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$host;
            proxy_read_timeout 86400;
        }
        location /vless-rafael {
            proxy_pass http://127.0.0.1:10002;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$host;
            proxy_buffering off; proxy_request_buffering off;
            chunked_transfer_encoding off; proxy_read_timeout 86400;
        }
        location /httpupgrade-rafael {
            proxy_pass http://127.0.0.1:11004;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$host;
            proxy_read_timeout 86400;
        }
    }
}
EOF

cat > entrypoint.sh <<EOF
#!/bin/sh
/usr/local/bin/xray run -c /etc/xray.json &
sleep 3
exec /usr/local/openresty/bin/openresty -g 'daemon off;'
EOF
chmod +x entrypoint.sh

cat > Dockerfile <<EOF
FROM alpine:3.19 AS xray-bin
RUN apk add --no-cache curl unzip ca-certificates bash
WORKDIR /app
RUN curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o xray.zip \
    && unzip xray.zip && chmod +x xray && mv xray /usr/local/bin/xray && rm -f xray.zip

FROM openresty/openresty:alpine-fat
RUN apk add --no-cache ca-certificates bash curl tzdata
COPY --from=xray-bin /usr/local/bin/xray /usr/local/bin/xray
COPY config.json /etc/xray.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/xray /entrypoint.sh
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
EOF

echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}Building Docker image...${NC}"
gcloud builds submit --tag gcr.io/$PROJECT_ID/$CLOUD_RUN_SERVICE_NAME . --quiet

BILLING_FLAGS=$([ "$BILLING_MODE" = "instance" ] && echo "--no-cpu-throttling" || echo "--cpu-throttling")

echo -e "${GREEN}Deploying to Cloud Run...${NC}"
gcloud run deploy $CLOUD_RUN_SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$CLOUD_RUN_SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --port 8080 \
  --memory $MEMORY \
  --cpu $CPU \
  --concurrency $CONCURRENCY \
  --timeout $TIMEOUT \
  --min-instances $MIN_INST \
  --max-instances $MAX_INST \
  --execution-environment gen2 \
  --cpu-boost \
  $BILLING_FLAGS \
  --quiet

CLOUD_RUN_URL=$(gcloud run services describe $CLOUD_RUN_SERVICE_NAME --region=$REGION --format='value(status.url)')

echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE${NC}"
echo -e "${GREEN}🔗 Cloud Run URL: $CLOUD_RUN_URL${NC}"
echo -e "${CYAN}=========================================${NC}"
