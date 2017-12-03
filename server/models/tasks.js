import mongoose from 'mongoose';

const {Schema} = mongoose;

// To fix https://github.com/Automattic/mongoose/issues/4291
mongoose.Promise = global.Promise;

const taskSchema = new Schema(
  {
    taskId: {type: Number},
    code: {type: String}
  },
  {versionKey: '__lock_key'}
);

export default mongoose.model('tasks', taskSchema);
