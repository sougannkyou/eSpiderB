import app from '../server/';
import supertest from 'supertest';
import {expect, should} from 'chai';

const temp = {};
const request = supertest.agent(app.listen());
should();

describe('POST /task', () => {
  it('should add a task', done => {
    request
      .post('/api/tasks')
      .set('Accept', 'application/json')
      .send({
        taskId: 11,
        code: 'test code'
      })
      .expect(200, (err, res) => {
        console.log('add a task:\n', res.body);
        temp.taskId = 11;
        done();
      });
  });
});

describe('GET /tasks', () => {
  it('should get all tasks', done => {
    request
      .get('/api/tasks')
      .set('Accept', 'application/json')
      .expect(200, (err, res) => {
        console.log('get all tasks:\n', res.body);
        expect(res.body.length).to.be.at.least(1);
        done();
      });
  });
});

describe('GET /tasks/:id', () => {
  it('should get a task', done => {
    request
      .get(`/api/tasks/${temp.taskId}`)
      .set('Accept', 'application/json')
      .expect(200, (err, res) => {
        console.log('get one task:\n', res.body);
        res.body.taskId.should.equal(11);
        res.body.code.should.equal('test code');
        done();
      });
  });
});

describe('PUT /task', () => {
  it('should update a task', done => {
    request
      .put(`/api/tasks/${temp.taskId}`)
      .set('Accept', 'application/json')
      .send({
        taskId: 12,
        code: 'new test code'
      })
      .expect(200, (err, res) => {
        console.log('update a task:\n', res.body);
        done();
      });
  });

  it('should get updated task', done => {
    request
      .get(`/api/tasks/12`)
      .set('Accept', 'application/json')
      .expect(200, (err, res) => {
        console.log('get updated task:\n', res.body);
        res.body.taskId.should.equal(12);
        res.body.code.should.equal('new test code');
        done();
      });
  });
});

describe('DELETE /tasks', () => {
  it('should delete a task', done => {
    request
      .delete(`/api/tasks/12`)
      .set('Accept', 'application/json')
      .expect(200, (err, res) => {
        console.log('dalete tasks:\n', res.body);
        done();
      });
  });
});
