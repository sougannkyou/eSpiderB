import 'babel-polyfill';
import Router from 'koa-router';
import {baseApi} from '../config';
import TasksControllers from '../controllers/tasks';

const api = 'tasks';

const router = new Router();

router.prefix(`/${baseApi}/${api}`);

// GET /api/tasks
router.get('/', TasksControllers.find);

// POST /api/tasks
// This route is protected, call POST /api/authenticate to get the token
router.post('/', TasksControllers.add);

// GET /api/tasks/id
// This route is protected, call POST /api/authenticate to get the token
router.get('/:id', TasksControllers.findByTaskId);

// PUT /api/tasks/id
// This route is protected, call POST /api/authenticate to get the token
router.put('/:id', TasksControllers.update);

// DELETE /api/tasks/id
// This route is protected, call POST /api/authenticate to get the token
router.delete('/:id', TasksControllers.delete);

export default router;
