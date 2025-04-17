// models/file.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const File = sequelize.define('File', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  file_name: {
    type: DataTypes.STRING,
    allowNull: false
  },
  s3_object_key: {
    type: DataTypes.STRING,
    allowNull: false
  },
  size: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  file_type: {
    type: DataTypes.STRING,
    allowNull: false
  }
}, {
  timestamps: true,
  createdAt: 'created_date',
  updatedAt: false
});

module.exports = File;