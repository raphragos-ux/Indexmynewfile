# 🚀 Rafael R. Config Generator
**VMess • VLESS • Trojan • Shadowsocks | GCP Cloud Run**

Isang buong proyekto para makabuo, mag-deploy, at gumamit ng mga proxy config na tumatakbo sa Google Cloud Run.

---

## 📁 Mga Kasamang File
| File Name         | Gamit / Deskripsyon |
|-------------------|---------------------|
| `index.html`      | Pahina ng generator na may mga kopyahing link at impormasyon |
| `deploy.sh`       | Automated script para i-build at i-deploy sa GCP Cloud Run |
| `Dockerfile`      | Tagubilin sa pagbuo ng container image |
| `config.json`     | Pangunahing setting ng Xray Core |
| `nginx.conf`      | Setting ng Nginx para pamahalaan ang koneksyon at port forwarding |
| `entrypoint.sh`   | Panimulang utos para patakbuhin ang mga serbisyo sa loob ng container |
| `README.md`       | Gabay na ito |

---

## ✅ Mga Kinakailangan Bago Magsimula
- May aktibong **Google Cloud account** na naka-set up ang billing
- Naka-install ang **gcloud CLI** o gumagamit ng **Google Cloud Shell**
- Naka-set ang tamang GCP project:
  ```bash
  gcloud config set project IYONG_PROJECT_ID
