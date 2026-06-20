import http from 'k6/http';
import { check, sleep } from 'k6';

// Кастомный сценарий: read-heavy (95% GET / 5% POST) — имитация просмотра заказов без создания
// Проверяем, как ведёт себя Nginx + backend при чтении vs write-heavy сценариях
export const options = {
  stages: [
    { duration: '30s', target: 100 },
    { duration: '1m', target: 400 },
    { duration: '1m', target: 400 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
};

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

export default function () {
  if (Math.random() < 0.95) {
    const res = http.get('http://localhost:8080/api/orders');
    check(res, { 'list ok': (r) => r.status === 200 });
  } else {
    const payload = JSON.stringify({
      user_id: randomInt(1, 2),
      amount: Math.random() * 100,
      description: 'k6 read-heavy',
    });
    const res = http.post('http://localhost:8081/api/orders', payload, {
      headers: { 'Content-Type': 'application/json' },
    });
    check(res, { 'created': (r) => r.status === 200 || r.status === 201 });
  }
  sleep(0.02);
}
