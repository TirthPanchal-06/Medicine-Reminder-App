const express = require('express');
const router = express.Router();
const { addMember, getMembers, updateMember, deleteMember } = require('../controllers/familyController');
const { protect } = require('../middlewares/auth');

router.use(protect);

router.route('/')
  .post(addMember)
  .get(getMembers);

router.route('/:id')
  .put(updateMember)
  .delete(deleteMember);

module.exports = router;
