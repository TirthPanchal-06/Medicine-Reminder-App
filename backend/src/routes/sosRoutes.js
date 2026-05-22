const express = require('express');
const router = express.Router();
const { addContact, getContacts, updateContact, deleteContact } = require('../controllers/sosController');
const { protect } = require('../middlewares/auth');

router.use(protect);

router.route('/')
  .post(addContact)
  .get(getContacts);

router.route('/:id')
  .put(updateContact)
  .delete(deleteContact);

module.exports = router;
