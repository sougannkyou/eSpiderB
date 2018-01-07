/* eslint-disable linebreak-style */
const request = require('request');
const {JSDOM} = require('jsdom');
const URL = 'http://127.0.0.1:4444/dashboard';
const client = require('mongodb').MongoClient;


async function update2db(taskId, status, updateTime) {
  try {
    const conn = await client.connect('mongodb://127.0.0.1:27017');
    const db = conn.db('eSpider');
    const tab = db.collection('tasks');
    await tab.update({'taskId': taskId}, {$set: {'status': status, 'updateTime': updateTime}});
    await console.log('[monitor] update:', taskId, status, updateTime);
    await conn.close();
  } catch (e) {
    console.error('[monitor] update2db error:', e.message);
  }
}

async function updateStatus() {
  await request({url: URL, method: "GET"}, (error, response, body) => {
      if (!error && response.statusCode === 200) {
        const jsdom = new JSDOM(body);
        const taskInfo = jsdom.window.document.querySelectorAll("li.nav-item > a");
        taskInfo.forEach((info, i) => {
          const taskId = info.getAttribute("data-test-build");
          const status = info.getAttribute("data-test-status");
          const updateTime = info.getAttribute("data-date-time");
          update2db(taskId, status, updateTime);
        });
      }
    }
  );
}

setInterval(updateStatus, 10000);


