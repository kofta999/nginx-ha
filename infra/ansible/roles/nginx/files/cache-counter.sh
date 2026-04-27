OUTPUT_FILE=/var/lib/node_exporter/cache.prom
LOG_FILE=/var/log/nginx/detailed-access.log
TEMP_FILE="${OUTPUT_FILE}.tmp"

awk -F' ' '
    $11 ~ /^(HIT|MISS|BYPASS|STALE)$/ { count[$11]++ }
    END {
        print "# HELP nginx_cache_requests_total Total number of Nginx cache requests by status."
        print "# TYPE nginx_cache_requests_total counter"
        for (i in count) {
            printf "nginx_cache_requests_total{status=\"%s\"} %d\n", tolower(i), count[i]
        }
    }
' "$LOG_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$OUTPUT_FILE"
