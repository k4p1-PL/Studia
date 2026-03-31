FROM scratch AS builder

ADD alpine-minirootfs-3.23.3-x86_64.tar.gz /

RUN apk add --no-cache go

ARG VERSION=1.0.0

WORKDIR /app

RUN echo 'package main' > main.go && \
    echo 'import ("fmt"; "net/http"; "os"; "net")' >> main.go && \
    echo 'func handler(w http.ResponseWriter, r *http.Request) {' >> main.go && \
    echo '	hostname, _ := os.Hostname()' >> main.go && \
    echo '	addrs, _ := net.LookupIP(hostname)' >> main.go && \
    echo '	ip := "nieznany"' >> main.go && \
    echo '	if len(addrs) > 0 { ip = addrs[0].String() }' >> main.go && \
    echo '	fmt.Fprintf(w, "<p><b>Wersja aplikacji:</b> %s</p>", "'$VERSION'")' >> main.go && \
    echo '	fmt.Fprintf(w, "<p><b>Hostname:</b> %s</p>", hostname)' >> main.go && \
    echo '	fmt.Fprintf(w, "<p><b>Adres IP serwera:</b> %s</p>", ip)' >> main.go && \
    echo '}' >> main.go && \
    echo 'func main() {' >> main.go && \
    echo '	http.HandleFunc("/", handler)' >> main.go && \
    echo '	http.ListenAndServe(":8080", nil)' >> main.go && \
    echo '}' >> main.go

RUN go build -o /my-web-app main.go

RUN echo 'server {' > /proxy.conf && \
    echo '    listen       80;' >> /proxy.conf && \
    echo '    server_name  localhost;' >> /proxy.conf && \
    echo '    location / {' >> /proxy.conf && \
    echo '        proxy_pass http://127.0.0.1:8080;' >> /proxy.conf && \
    echo '    }' >> /proxy.conf && \
    echo '}' >> /proxy.conf

RUN echo '#!/bin/sh' > /start.sh && \
    echo '/usr/local/bin/my-web-app & ' >> /start.sh && \
    echo 'nginx -g "daemon off;"' >> /start.sh && \
    chmod +x /start.sh

FROM nginx:alpine

COPY --from=builder /my-web-app /usr/local/bin/my-web-app

COPY --from=builder /proxy.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /start.sh /start.sh

HEALTHCHECK --interval=10s --timeout=3s \
  CMD curl -f http://localhost/ || exit 1

EXPOSE 80

CMD ["/start.sh"]