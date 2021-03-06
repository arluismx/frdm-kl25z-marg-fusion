/*
* sensor_calibration.h
*
*  Created on: Jan 18, 2014
*      Author: Markus
*/

#ifndef SENSOR_CALIBRATIOn_H
#define SENSOR_CALIBRATIOn_H

#include "compiler.h"
#include "fixmath.h"
#include "fixvector3d.h"

/*!
* \brief Calibrates MPU6050 accelerometer sensor data
* \param[inout] x The x data (will be overwritten with the calibrated version)
* \param[inout] y The y data (will be overwritten with the calibrated version)
* \param[inout] z The z data (will be overwritten with the calibrated version)
*/
HOT NONNULL
void mpu6050_calibrate_accelerometer(register fix16_t *RESTRICT const x, register fix16_t *RESTRICT const y, register fix16_t *RESTRICT const z);

/*!
* \brief Calibrates MPU6050 accelerometer sensor data
* \param[inout] data The data (will be overwritten with the calibrated version)
*/
HOT NONNULL
STATIC_INLINE void mpu6050_calibrate_accelerometer_v3d(register v3d *const data)
{
    mpu6050_calibrate_accelerometer(&data->x, &data->y, &data->z);
}

/*!
* \brief Calibrates MPU6050 gyroscope sensor data
* \param[inout] x The x data (will be overwritten with the calibrated version)
* \param[inout] y The y data (will be overwritten with the calibrated version)
* \param[inout] z The z data (will be overwritten with the calibrated version)
*/
HOT NONNULL
void mpu6050_calibrate_gyroscope(register fix16_t *RESTRICT const x, register fix16_t *RESTRICT const y, register fix16_t *RESTRICT const z);

/*!
* \brief Calibrates MPU6050 gyroscope sensor data
* \param[inout] data The data (will be overwritten with the calibrated version)
*/
HOT NONNULL
STATIC_INLINE void mpu6050_calibrate_gyroscope_v3d(register v3d *const data)
{
    mpu6050_calibrate_gyroscope(&data->x, &data->y, &data->z);
}

/*!
* \brief Calibrates HMC5883L magnetometer sensor data
* \param[inout] x The x data (will be overwritten with the calibrated version)
* \param[inout] y The y data (will be overwritten with the calibrated version)
* \param[inout] z The z data (will be overwritten with the calibrated version)
*/
HOT NONNULL
void hmc5883l_calibrate(register fix16_t *RESTRICT const x, register fix16_t *RESTRICT const y, register fix16_t *RESTRICT const z);

/*!
* \brief Calibrates HMC5883L magnetometer sensor data
* \param[inout] data The data (will be overwritten with the calibrated version)
*/
HOT NONNULL
STATIC_INLINE void hmc5883l_calibrate_v3d(register v3d *const data)
{
    hmc5883l_calibrate(&data->x, &data->y, &data->z);
}

/*!
* \brief Retrieves the variances of the MPU6050 accelerometer
* \param[out] x The x axis variances
* \param[out] y The y axis variances
* \param[out] z The z axis variances
*/
LEAF NONNULL
void mpu6050_var_accelerometer(register fix16_t *const RESTRICT x, register fix16_t *const RESTRICT y, register fix16_t *const RESTRICT z);

/*!
* \brief Retrieves the variances of the MPU6050 gyroscope
* \param[out] x The x axis variances
* \param[out] y The y axis variances
* \param[out] z The z axis variances
*/
LEAF NONNULL
void mpu6050_var_gyroscope(register fix16_t *const RESTRICT x, register fix16_t *const RESTRICT y, register fix16_t *const RESTRICT z);

/*!
* \brief Retrieves the variances of the HMC5883L magnetometer
* \param[out] x The x axis variances
* \param[out] y The y axis variances
* \param[out] z The z axis variances
*/
LEAF NONNULL
void hmc5883l_var(register fix16_t *const RESTRICT x, register fix16_t *const RESTRICT y, register fix16_t *const RESTRICT z);

#endif // SENSOR_CALIBRATIOn_H