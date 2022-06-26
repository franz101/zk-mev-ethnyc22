const express = require("express");
const { executeRunner } = require("./runner");
const JSONdb = require("simple-json-db");
const db = new JSONdb("storage/db.json", { asyncWrite: true });
const app = express();
const port = 4000;

app.use(express.json());

app.post("/add_bider", (req, res) => {
  const { bidder, collection, maxValue } = req.body;
  db.set(collection, { bidder, maxValue });
  db.sync();
  res.send(req.body);
});

app.get("/start_runner", async (req, res) => {
  const database = db.JSON();
  for (const objectKey of Object.keys(database)) {
    const result = await executeRunner(objectKey, database[objectKey]);
    console.log(result);
    db.delete(objectKey);
  }

  res.send("Runner started");
});

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`);
});
