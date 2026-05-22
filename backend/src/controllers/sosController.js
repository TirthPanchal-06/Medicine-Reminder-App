const SOSContact = require('../models/SOSContact');

// @desc    Add an SOS contact
// @route   POST /api/sos
// @access  Private
exports.addContact = async (req, res) => {
  const { name, phone, relationship, isEmergency } = req.body;

  try {
    const contact = await SOSContact.create({
      userId: req.user._id,
      name,
      phone,
      relationship,
      isEmergency: isEmergency !== undefined ? isEmergency : true
    });

    res.status(201).json({ success: true, data: contact });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get all SOS contacts for user
// @route   GET /api/sos
// @access  Private
exports.getContacts = async (req, res) => {
  try {
    const contacts = await SOSContact.find({ userId: req.user._id }).sort({ name: 1 });
    res.json({ success: true, count: contacts.length, data: contacts });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update SOS contact
// @route   PUT /api/sos/:id
// @access  Private
exports.updateContact = async (req, res) => {
  try {
    let contact = await SOSContact.findOne({ _id: req.params.id, userId: req.user._id });
    if (!contact) {
      return res.status(404).json({ success: false, message: 'SOS Contact not found' });
    }

    contact = await SOSContact.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true
    });

    res.json({ success: true, data: contact });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete SOS contact
// @route   DELETE /api/sos/:id
// @access  Private
exports.deleteContact = async (req, res) => {
  try {
    const contact = await SOSContact.findOne({ _id: req.params.id, userId: req.user._id });
    if (!contact) {
      return res.status(404).json({ success: false, message: 'SOS Contact not found' });
    }

    await SOSContact.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'SOS Contact removed successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
