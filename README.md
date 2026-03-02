🚀 Однокнопочный скрипт для получения ACME-сертификата
(для локального IP VPS)

🔹 Быстрый запуск
bash <(curl -Ls https://raw.githubusercontent.com/MyNicknme/Acme/refs/heads/main/Acme-yonggekkk.sh)

<img width="830" height="588" alt="image" src="https://github.com/user-attachments/assets/583e9207-9a6e-426d-b35c-b57176433944" />


Интеграция со следующими прокси-скриптами
(можно использовать один общий сертификат):
4protocol
x-ui

⚠️ Важно
При использовании режима через порт 80:
порт 80 будет принудительно освобождён
не рекомендуется одновременно использовать nginx, caddy или другие сервисы с авто-получением сертификатов
