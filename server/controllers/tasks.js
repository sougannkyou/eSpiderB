import Tasks from '../models/tasks';

class TasksControllers {
  /* eslint-disable no-param-reassign */

  /**
   * Get all tasks
   * @param {ctx} Koa Context
   */
  async find(ctx) {
    ctx.body = await Tasks.find();
    console.log('find', ctx.body);
  }

  /**
   * Find a task
   * @param {ctx} Koa Context
   */
  async findByTaskId(ctx) {
    try {
      const task = await Tasks.find({taskId: ctx.params.id});
      if (!task) {
        ctx.throw(404);
      }
      ctx.body = task;
      console.log('findByTaskId', task);
    } catch (err) {
      if (err.name === 'CastError' || err.name === 'NotFoundError') {
        ctx.throw(404);
      }
      ctx.throw(500);
    }
  }

  /**
   * Add a task
   * @param {ctx} Koa Context
   */
  async add(ctx) {
    console.log('add ...');
    try {
      const task = await new Tasks(ctx.request.body).save();
      ctx.body = task;
      console.log('add', task);
    } catch (err) {
      ctx.throw(422);
    }
  }

  /**
   * Update a task
   * @param {ctx} Koa Context
   */
  async update(ctx) {
    try {
      const task = await Tasks.update({taskId: ctx.params.id}, ctx.request.body);
      if (!task) {
        ctx.throw(404);
      }
      ctx.body = task;
      console.log('update', task);
    } catch (err) {
      if (err.name === 'CastError' || err.name === 'NotFoundError') {
        ctx.throw(404);
      }
      ctx.throw(500);
    }
  }

  /**
   * Delete a task
   * @param {ctx} Koa Context
   */
  async delete(ctx) {
    try {
      const task = await Tasks.deleteMany({taskId: ctx.params.id});
      if (!task) {
        ctx.throw(404);
      }
      ctx.body = task;
    } catch (err) {
      if (err.name === 'CastError' || err.name === 'NotFoundError') {
        ctx.throw(404);
      }
      ctx.throw(500);
    }
  }

  /* eslint-enable no-param-reassign */
}

export default new TasksControllers();
