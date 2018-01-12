/* eslint-disable linebreak-style */
import mongoose from 'mongoose';

const {Schema} = mongoose;

// To fix https://github.com/Automattic/mongoose/issues/4291
mongoose.Promise = global.Promise;

const taskSchema = new Schema(
  {
    taskId: {type: String},
    status: {type: String},
    startUrl: {type: String},
    code: {type: String},
    result: {type: String},
    priority: {type: Number}
  },
  {versionKey: '__lock_key'}
);

export default mongoose.model('tasks', taskSchema);
