exports.handler = async (event) => {
  try {
    const chromium = require('chrome-aws-lambda');
    return { statusCode: 200, body: 'chrome-aws-lambda loaded!' };
  } catch (err) {
    return { statusCode: 500, body: err.toString() };
  }
}; 