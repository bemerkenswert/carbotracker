#!/usr/bin/env node
'use strict';

// Validate a review plan JSON file against the review-comments plan schema.
// Usage: node tools/ct-review-plan-validate.js <schema> <plan-file>
// Exit codes: 0 the plan is valid; 1 the plan is invalid or unreadable;
// 2 the invocation or the schema itself is wrong.

const fs = require('fs');
const path = require('path');

if (process.argv.length !== 4) {
  console.error('usage: ct-review-plan-validate.js <schema> <plan-file>');
  process.exit(2);
}

const schemaPath = process.argv[2];
const planPath = process.argv[3];

let Ajv;
try {
  const ajvRoot = path.resolve(__dirname, '..', 'node_modules', 'ajv');
  Ajv = require(ajvRoot);
} catch (err) {
  console.error('ajv is not available; run npm install first');
  process.exit(2);
}

let schema;
let plan;
try {
  schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
} catch (err) {
  console.error(`cannot read schema ${schemaPath}: ${err.message}`);
  process.exit(2);
}
try {
  plan = JSON.parse(fs.readFileSync(planPath, 'utf8'));
} catch (err) {
  console.error(`cannot read plan ${planPath}: ${err.message}`);
  process.exit(1);
}

const ajv = new Ajv({ allErrors: true });
let validate;
try {
  validate = ajv.compile(schema);
} catch (err) {
  console.error(`schema does not compile: ${err.message}`);
  process.exit(2);
}

const valid = validate(plan);
if (!valid) {
  for (const e of validate.errors) {
    console.error(
      `${e.instancePath || '/'} ${e.message}${e.params ? ' ' + JSON.stringify(e.params) : ''}`,
    );
  }
  process.exit(1);
}
process.exit(0);
