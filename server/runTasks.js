const CONTENT_WS_PORT = 8181;
const WebSocket = require('ws');
const contentWS = new WebSocket('ws://127.0.0.1:' + CONTENT_WS_PORT);
const path = require('path');
const fs = require('fs');

const ROOT_PATH = path.normalize('./temp');
const SIMULATION_DB_PATH = path.normalize('../database/db-simulation.json');
const ADBLOCK_PATH = path.normalize('../assets/adblock/AdBlock_v3.14.0.crx');
const low = require('lowdb');
const FileSync = require('lowdb/adapters/FileSync');
const simAdapter = new FileSync(SIMULATION_DB_PATH);
const simulationDB = low(simAdapter);

const chrome = require('selenium-webdriver/chrome');
const firefox = require('selenium-webdriver/firefox');
let webdriver = require('selenium-webdriver');
let By = webdriver.By;
let Key = webdriver.Key;
let until = webdriver.until;
let promise = webdriver.promise;

const client = require('mongodb').MongoClient;

async function getCode(taskId) {
  try {
    const conn = await client.connect('mongodb://127.0.0.1:27017');
    const db = conn.db('eSpider');
    const tab = db.collection('tasks');
    const ret = await tab.find({'taskId': taskId});
    // await db.close();
    return ret.code;
  } catch (e) {
    console.error('[monitor] update2db error:', e.message);
  }
  return '';
}

let taskId = 'eSpider20180106115353';
let code = getCode(taskId);
console.log('code:', code);
let codeFile = taskId + '.js';
fs.writeFileSync(codeFile, code, 'utf-8');

delete require.cache[require.resolve(codeFile)];
const run = new require(codeFile);
run.simulation(
  contentWS,
  simulationDB,
  webdriver, until, By, Key, promise, chrome,
  SIMULATION_DB_PATH, ADBLOCK_PATH,
  taskId
);
