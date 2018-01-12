/* eslint-disable linebreak-style */
const CONTENT_WS_PORT = 8181;
const WebSocket = require('ws');
const moment = require('moment');
const contentWS = new WebSocket(`ws://127.0.0.1:${CONTENT_WS_PORT}`);
const path = require('path');
const fs = require('fs');

function getRootPath() {
  const n = __dirname.split(path.sep);
  for (let i = n.length; i > 0; i--) {
    const name = n.pop();
    if (name.startsWith('eSpiderB') && name !== 'eSpiderB.app') {
      return n.join(path.sep) + path.sep + name;
    }
  }
  return __dirname;
}

const ROOT_PATH = path.normalize(getRootPath());
const SIMULATION_DB_PATH = path.normalize(`${ROOT_PATH}/database/db-simulation.json`);
const ADBLOCK_PATH = path.normalize(`${ROOT_PATH}/assets/adblock/AdBlock_v3.14.0.crx`);
const MAKECODE_PATH = path.normalize(`${ROOT_PATH}/makecode/`);

const low = require('lowdb');
const FileSync = require('lowdb/adapters/FileSync');

const simAdapter = new FileSync(SIMULATION_DB_PATH);
const simulationDB = low(simAdapter);

const chrome = require('selenium-webdriver/chrome');
const firefox = require('selenium-webdriver/firefox');
const webdriver = require('selenium-webdriver');

const By = webdriver.By;
const Key = webdriver.Key;
const until = webdriver.until;
const promise = webdriver.promise;

const client = require('mongodb').MongoClient;

async function runTask(taskId) {
  try {
    const conn = await client.connect('mongodb://127.0.0.1:27017');
    const db = conn.db('eSpider');
    const tab = db.collection('tasks');
    const ret = await tab.find({'taskId': taskId, 'status': 'Wait'}).toArray();
    if (ret && ret[0]) {
      // console.info('[runTask] code\n', ret[0].code);
      await fs.writeFileSync(`${MAKECODE_PATH}${taskId}.js`, ret[0].code, 'utf-8');
      delete require.cache[require.resolve(`${MAKECODE_PATH}${taskId}.js`)];
      const run = new require(`${MAKECODE_PATH}${taskId}.js`);
      run.simulation(contentWS, simulationDB, webdriver, until, By, Key, promise, chrome, SIMULATION_DB_PATH, ADBLOCK_PATH, taskId);
      await tab.update({'taskId': taskId}, {
        $set: {
          'status': 'Run',
          'updateTime': moment().format('YYYY-MM-DD HH:mm:ss')
        }
      });
    }
    await conn.close();
  } catch (e) {
    console.error('[runTask] error:', e.message);
  }
}

const taskId = 'eSpider20180108145802';
runTask(taskId);

