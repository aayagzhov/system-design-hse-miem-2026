Предупреждение безопасности: риск выполнения сценария
Invoke-WebRequest анализирует содержимое веб-страницы. При анализе страницы может выполняться код сценария на веб-странице.
      РЕКОМЕНДУЕМОЕ ДЕЙСТВИЕ:                          
      Используйте параметр -UseBasicParsing, чтобы предотвратить выполнение кода сценария.
                                                
      Продолжить?
    
[Y] Да - Y  [A] Да для всех - A  [N] Нет - N  [L] Нет для всех - L  [S] Приостановить - S  [?] Справка (значением по умолчанию является "N"): Y


StatusCode        : 200
StatusDescription : OK
Content           : []
                    
RawContent        : HTTP/1.1 200 OK
                    Content-Length: 3
                    Content-Type: application/json
                    Date: Sat, 20 Jun 2026 07:13:11 GMT
                    
                    []
                    
Forms             : {}
Headers           : {[Content-Length, 3], [Content-Type, application/json], [Date, Sat, 20 Jun 2026 07:13:11 GMT]}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : mshtml.HTMLDocumentClass
RawContentLength  : 3



PS C:\Users\User\CppProjects\system-design-hse-miem-2026\code\demo-app-1> Invoke-RestMethod -Uri http://localhost:8081/api/users -Method Post -ContentType "application/json" -Body '{"name":"User1","email":"u1@test.com"}'

id name  email       created_at                 
-- ----  -----       ----------                 
 1 User1 u1@test.com 2026-06-20T07:13:26.459728Z


PS C:\Users\User\CppProjects\system-design-hse-miem-2026\code\demo-app-1> Invoke-RestMethod -Uri http://localhost:8081/api/users -Method Post -ContentType "application/json" -Body '{"name":"User2","email":"u2@test.com"}'

id name  email       created_at                 
-- ----  -----       ----------                 
 2 User2 u2@test.com 2026-06-20T07:13:37.438495Z


PS C:\Users\User\CppProjects\system-design-hse-miem-2026\code\demo-app-1> docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/storm.js
time="2026-06-20T10:26:29+03:00" level=warning msg="C:\\Users\\User\\CppProjects\\system-design-hse-miem-2026\\code\\demo-app-1\\docker-compose.yaml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion"
[+] Creating 3/3
 ✔ Container demo-app-1-db-1       Running                                                                                                                  0.0s 
 ✔ Container demo-app-1-backend-1  Running                                                                                                                  0.0s 
 ✔ Container demo-app-1-nginx-1    Running                                                                                                                  0.0s 

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 


     execution: local
        script: /scripts/storm.js
        output: Prometheus remote write (http://localhost:9090/api/v1/write)

     scenarios: (100.00%) 1 scenario, 1000 max VUs, 2m10s max duration (incl. graceful stop):
              * default: Up to 1000 looping VUs for 1m40s over 3 stages (gracefulRampDown: 30s, gracefulStop: 30s)



  █ THRESHOLDS 

    http_req_duration
    ✗ 'p(95)<2000' p(95)=2.01s

    http_req_failed
    ✗ 'rate<0.05' rate=13.15%


  █ TOTAL RESULTS 

    checks_total.......: 130268 1357.694733/s
    checks_succeeded...: 86.84% 113125 out of 130268
    checks_failed......: 13.15% 17143 out of 130268

    ✗ created
      ↳  86% — ✓ 90485 / ✗ 13611
    ✗ list ok
      ↳  86% — ✓ 22640 / ✗ 3532

    HTTP
    http_req_duration..............: avg=546.68ms min=38.53µs med=184.1ms  max=35.55s p(90)=1.56s    p(95)=2.01s
      { expected_response:true }...: avg=459.23ms min=38.53µs med=24.87ms  max=35.55s p(90)=847.82ms p(95)=1.84s
    http_req_failed................: 13.15% 17143 out of 130268
    http_reqs......................: 130268 1357.694733/s

    EXECUTION
    iteration_duration.............: avg=621.94ms min=51.67ms med=266.83ms max=36.95s p(90)=1.65s    p(95)=2.17s
    iterations.....................: 130268 1357.694733/s
    vus............................: 6      min=6               max=1000
    vus_max........................: 1000   min=1000            max=1000

    NETWORK
    data_received..................: 275 MB 2.9 MB/s
    data_sent......................: 23 MB  237 kB/s




running (1m35.9s), 0000/1000 VUs, 130268 complete and 0 interrupted iterations
default ✓ [======================================] 0000/1000 VUs  1m40s
ERRO[0100] thresholds on metrics 'http_req_duration, http_req_failed' have been crossed 

PS C:\Users\User\CppProjects\system-design-hse-miem-2026\code\demo-app-1> docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/wave.js
time="2026-06-20T10:28:51+03:00" level=warning msg="C:\\Users\\User\\CppProjects\\system-design-hse-miem-2026\\code\\demo-app-1\\docker-compose.yaml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion"
[+] Creating 3/3
 ✔ Container demo-app-1-db-1       Running                                                                                                                  0.0s 
 ✔ Container demo-app-1-backend-1  Running                                                                                                                  0.0s 
 ✔ Container demo-app-1-nginx-1    Running                                                                                                                  0.0s 

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 


     execution: local
        script: /scripts/wave.js
        output: Prometheus remote write (http://localhost:9090/api/v1/write)

     scenarios: (100.00%) 1 scenario, 500 max VUs, 5m30s max duration (incl. graceful stop):
              * default: Up to 500 looping VUs for 5m0s over 3 stages (gracefulRampDown: 30s, gracefulStop: 30s)



  █ THRESHOLDS 

    http_req_duration
    ✓ 'p(95)<1500' p(95)=765.37ms

    http_req_failed
    ✗ 'rate<0.02' rate=15.47%


  █ TOTAL RESULTS 

    checks_total.......: 314105 1099.137048/s
    checks_succeeded...: 84.52% 265488 out of 314105
    checks_failed......: 15.47% 48617 out of 314105

    ✗ created
      ↳  84% — ✓ 213315 / ✗ 38109
    ✗ list ok
      ↳  83% — ✓ 52173 / ✗ 10508

    HTTP
    http_req_duration..............: avg=227.11ms min=-917673720ns med=92.16ms  max=2.58s p(90)=575.43ms p(95)=765.37ms
      { expected_response:true }...: avg=199.88ms min=-917673720ns med=28.69ms  max=2.58s p(90)=541.14ms p(95)=715.85ms
    http_req_failed................: 15.47% 48617 out of 314105
    http_reqs......................: 314105 1099.137048/s

    EXECUTION
    iteration_duration.............: avg=334.59ms min=101.75ms     med=208.14ms max=2.83s p(90)=689.21ms p(95)=884.85ms
    iterations.....................: 314105 1099.137048/s
    vus............................: 1      min=1               max=500
    vus_max........................: 500    min=500             max=500

    NETWORK
    data_received..................: 632 MB 2.2 MB/s
    data_sent......................: 55 MB  191 kB/s




running (4m45.8s), 000/500 VUs, 314105 complete and 0 interrupted iterations
default ✓ [======================================] 000/500 VUs  5m0s
ERRO[0303] thresholds on metrics 'http_req_failed' have been crossed 

PS C:\Users\User\CppProjects\system-design-hse-miem-2026\code\demo-app-1> git pull origin
Updating 0faf65e..b2aebc0
Fast-forward
 .../Postgres Overview-1760906099251.json           |  24 ++--
 .../dashboards/k6 Prometheus-1760906025550.json    | 144 +++++++--------------
 2 files changed, 56 insertions(+), 112 deletions(-)
PS C:\Users\User\CppProjects\system-design-hse-miem-2026\code\demo-app-1> docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/read-heavy.js
time="2026-06-20T10:36:25+03:00" level=warning msg="C:\\Users\\User\\CppProjects\\system-design-hse-miem-2026\\code\\demo-app-1\\docker-compose.yaml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion"
[+] Creating 3/3
 ✔ Container demo-app-1-db-1       Running                                                                                                                  0.0s 
 ✔ Container demo-app-1-backend-1  Running                                                                                                                  0.0s 
 ✔ Container demo-app-1-nginx-1    Running                                                                                                                  0.0s 

         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 


     execution: local
        script: /scripts/read-heavy.js
        output: Prometheus remote write (http://localhost:9090/api/v1/write)

     scenarios: (100.00%) 1 scenario, 400 max VUs, 3m30s max duration (incl. graceful stop):
              * default: Up to 400 looping VUs for 3m0s over 4 stages (gracefulRampDown: 30s, gracefulStop: 30s)



  █ THRESHOLDS 

    http_req_duration
    ✓ 'p(95)<500' p(95)=461.72ms

    http_req_failed
    ✗ 'rate<0.01' rate=66.68%


  █ TOTAL RESULTS 

    checks_total.......: 299469 1750.47186/s
    checks_succeeded...: 33.31% 99755 out of 299469
    checks_failed......: 66.68% 199714 out of 299469

    ✗ list ok
      ↳  29% — ✓ 84693 / ✗ 199714
    ✓ created

    HTTP
    http_req_duration..............: avg=132.35ms min=-922910827ns med=91.25ms  max=1.6s  p(90)=315.89ms p(95)=461.72ms
      { expected_response:true }...: avg=147.13ms min=-922910827ns med=26.55ms  max=1.07s p(90)=527.18ms p(95)=611.25ms
    http_req_failed................: 66.68% 199714 out of 299469
    http_reqs......................: 299469 1750.47186/s

    EXECUTION
    iteration_duration.............: avg=155.32ms min=21.55ms      med=113.23ms max=1.62s p(90)=340.9ms  p(95)=490.22ms
    iterations.....................: 299469 1750.47186/s
    vus............................: 2      min=2                max=400
    vus_max........................: 400    min=400              max=400

    NETWORK
    data_received..................: 1.0 GB 6.1 MB/s
    data_sent......................: 26 MB  151 kB/s




running (2m51.1s), 000/400 VUs, 299469 complete and 0 interrupted iterations
default ✓ [======================================] 000/400 VUs  3m0s
ERRO[0180] thresholds on metrics 'http_req_failed' have been crossed 

PS C:\Users\User\CppProjects\system-design-hse-miem-2026\code\demo-app-1> 



























