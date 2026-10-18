'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const { createServer } = require('../src/server');

test('configured responses, local counter, health, and fresh instance', async () => {
  const server = createServer({serviceName:'test-service', message:'test-message'});
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = 'http://127.0.0.1:' + server.address().port;
  try {
    const first = await fetch(base + '/');
    assert.equal(first.status, 200);
    const body = await first.json();
    assert.equal(body.service, 'test-service');
    assert.equal(body.message, 'test-message');
    assert.equal(typeof body.hostname, 'string');
    assert.equal(body.requestCount, 1);
    const health = await fetch(base + '/health');
    assert.equal(health.status, 200);
    assert.deepEqual(await health.json(), {status:'ok'});
    assert.equal((await (await fetch(base + '/')).json()).requestCount, 2);
    const missing = await fetch(base + '/missing');
    assert.equal(missing.status, 404);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
  const fresh = createServer();
  fresh.listen(0, '127.0.0.1');
  await once(fresh, 'listening');
  try {
    const response = await fetch('http://127.0.0.1:' + fresh.address().port + '/');
    assert.equal((await response.json()).requestCount, 1);
  } finally {
    await new Promise(resolve => fresh.close(resolve));
  }
});

test('readiness file toggles health without resetting the root counter', async () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'cs554-readiness-'));
  const readinessFile = path.join(directory, 'ready');
  const previous = process.env.READINESS_FILE;
  process.env.READINESS_FILE = readinessFile;
  const server = createServer();
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = 'http://127.0.0.1:' + server.address().port;
  try {
    const missing = await fetch(base + '/health');
    assert.equal(missing.status, 503);
    assert.deepEqual(await missing.json(), {status:'not-ready'});
    const first = await fetch(base + '/');
    assert.equal(first.status, 200);
    assert.equal((await first.json()).requestCount, 1);
    fs.writeFileSync(readinessFile, '', {encoding:'utf8'});
    const ready = await fetch(base + '/health');
    assert.equal(ready.status, 200);
    assert.deepEqual(await ready.json(), {status:'ok'});
    assert.equal((await (await fetch(base + '/')).json()).requestCount, 2);
    fs.unlinkSync(readinessFile);
    assert.equal((await fetch(base + '/health')).status, 503);
    assert.equal((await (await fetch(base + '/')).json()).requestCount, 3);
  } finally {
    await new Promise(resolve => server.close(resolve));
    if (previous === undefined) delete process.env.READINESS_FILE;
    else process.env.READINESS_FILE = previous;
    fs.rmSync(directory, {recursive:true, force:true});
  }
});
