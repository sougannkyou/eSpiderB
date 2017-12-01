import 'babel-polyfill';
import Router from 'koa-router';
import { baseApi } from '../config';
import jwt from '../middlewares/jwt';
import TasksControllers from '../controllers/tasks';

const api = 'tasks';

const router = new Router();

router.prefix(`/${baseApi}/${api}`);

// GET /api/cities
router.get('/', TasksControllers.find);

// POST /api/cities
// This route is protected, call POST /api/authenticate to get the token
router.post('/', jwt, TasksControllers.add);

// GET /api/cities/id
// This route is protected, call POST /api/authenticate to get the token
router.get('/:id', jwt, TasksControllers.findById);

// PUT /api/cities/id
// This route is protected, call POST /api/authenticate to get the token
router.put('/:id', jwt, TasksControllers.update);

// DELETE /api/cities/id
// This route is protected, call POST /api/authenticate to get the token
router.delete('/:id', jwt, TasksControllers.delete);

export default router;
