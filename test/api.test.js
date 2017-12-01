import app from '../server/';
import supertest from 'supertest';
import { expect, should } from 'chai';

const temp = {};
const request = supertest.agent(app.listen());
should();

describe('POST api/authenticate', () => {
  it('should get all cities', done => {
    request
      .post('/api/authenticate')
      .set('Accept', 'application/json')
      .send({
        password: 'password'
      })
      .expect(200, (err, res) => {
        temp.token = res.body.token;
        done();
      });
  });
});

describe('POST /task', () => {
  it('should add a task', done => {
    request
      .post('/api/tasks')
      .set('Accept', 'application/json')
      .set('Authorization', `Bearer ${temp.token}`)
      .set('Accept', 'application/json')
      .send({
        name: 'Bangkok',
        totalPopulation: 8249117,
        country: 'Thailand',
        zipCode: 1200
      })
      .expect(200, (err, res) => {
        temp.idCity = res.body._id;
        done();
      });
  });
});

describe('GET /tasks', () => {
  it('should get all tasks', done => {
    request
      .get('/api/tasks')
      .set('Authorization', `Bearer ${temp.token}`)
      .set('Accept', 'application/json')
      .expect(200, (err, res) => {
        expect(res.body.length).to.be.at.least(1);
        done();
      });
  });
});

describe('GET /tasks/:id', () => {
  it('should get a task', done => {
    request
      .get(`/api/tasks/${temp.idCity}`)
      .set('Authorization', `Bearer ${temp.token}`)
      .set('Accept', 'application/json')
      .expect(200, (err, res) => {
        res.body.name.should.equal('Bangkok');
        res.body.totalPopulation.should.equal(8249117);
        res.body.country.should.equal('Thailand');
        res.body.zipCode.should.equal(1200);
        res.body._id.should.equal(temp.idCity);
        done();
      });
  });
});

describe('PUT /task', () => {
  it('should update a task', done => {
    request
      .put(`/api/tasks/${temp.idCity}`)
      .set('Authorization', `Bearer ${temp.token}`)
      .set('Accept', 'application/json')
      .send({
        name: 'Chiang Mai',
        totalPopulation: 148477,
        country: 'Thailand',
        zipCode: 50000
      })
      .expect(200, (err, res) => {
        temp.idCity = res.body._id;
        done();
      });
  });

  it('should get updated task', done => {
    request
      .get(`/api/tasks/${temp.idCity}`)
      .set('Authorization', `Bearer ${temp.token}`)
      .set('Accept', 'application/json')
      .expect(200, (err, res) => {
        res.body.name.should.equal('Chiang Mai');
        res.body.totalPopulation.should.equal(148477);
        res.body.country.should.equal('Thailand');
        res.body.zipCode.should.equal(50000);
        res.body._id.should.equal(temp.idCity);
        done();
      });
  });
});

describe('DELETE /tasks', () => {
  it('should delete a task', done => {
    request
      .delete(`/api/tasks/${temp.idCity}`)
      .set('Authorization', `Bearer ${temp.token}`)
      .set('Accept', 'application/json')
      .expect(200, (err, res) => {
        done();
      });
  });

  it('should get error', done => {
    request
      .get(`/api/cities/${temp.idCity}`)
      .set('Accept', 'application/json')
      .expect(404, () => {
        done();
      });
  });
});
