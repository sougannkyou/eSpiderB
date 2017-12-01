import jwt from 'koa-jwt';

export default jwt({
  secret: 'An electron spider'
});
