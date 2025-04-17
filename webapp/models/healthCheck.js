const { DataTypes, Sequelize: { NOW } } = require('sequelize');
const sequelize = require('../config/database');

const HealthCheck = sequelize.define('HealthCheck', {
  checkId: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
    field: 'check_id'
  },
  datetime: {
    type: DataTypes.DATE,
    defaultValue: NOW,
    allowNull: false
  }
}, {
  tableName: 'health_check',
  timestamps: false
});

module.exports = HealthCheck;