// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SharePay is OwnableUpgradeable {
    struct Bill {
        uint id;
        uint amount;
        uint remainder_index;
        uint delta;
        uint last_payment;
        address owner;
        string title;
        address[] participants;
        address[] paused_participants;
        address[] requests;
    }

    error ErrBillDoesNotExist();
    error ErrBillExists();
    error ErrIdNotFound();
    error ErrUnauthorized();
    error ErrPendingRequest();
    error ErrAlreadyParticipant();

    event ArchiveBill(uint indexed id, address indexed owner, string indexed title, Bill bill);

    uint private _next_id = 0;
    uint[] private _available_ids;
    uint immutable private _max_available_ids = 1000;
    mapping(uint => Bill) private _bills;
    mapping(address => uint) private _balances;
    mapping(address => uint[]) private _bill_list;
    mapping(address => uint) private _request_count;

    constructor() initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);
    }

    function initialize() public initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);
    }

    receive() external payable {
        deposit();
    }

    modifier billExists(uint id) {
        Bill memory b = _bills[id];
        require(!isBillNull(b), ErrBillDoesNotExist());

        _;
    }

    modifier billNotExists(address _bill_owner, string calldata _title) {
        for (uint i = 0; i < _bill_list[_bill_owner].length; i++) {
            if (areStringsEqual(_bills[_bill_list[_bill_owner][i]].title, _title)) {
                revert ErrBillExists();
            }
        }

        _;
    }

    function areStringsEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    /* Bill Manipulations */

    // Create a null bill
    function nullBill() public view returns (Bill memory) {
        return Bill(0, 0, 0, 0, 0, msg.sender, "", new address[](0), new address[](0), new address[](0));
    }

    // Check if a bill is null
    function isBillNull(Bill memory b) public pure returns(bool) {
        return b.amount == 0;
    }

    function setBillToNull(uint id) private {
        require(_bills[id].owner == msg.sender, ErrUnauthorized());

        _bills[id].amount = 0;
    }

    function getNextId() private returns(uint) {
        uint retval = 0;
        if (_available_ids.length > 0) {
            retval = _available_ids[_available_ids.length - 1];
            _available_ids.pop();
        } else {
            uint count = 0;
            for (;!isBillNull(_bills[_next_id]) && count < _max_available_ids; count++) {
                unchecked {
                    _next_id++;
                }
            }

            require(count < _max_available_ids, ErrIdNotFound());

            retval = _next_id;
            unchecked {
                _next_id++;
            }
        }

        return retval;
    }

    function addBillToUser(address user, uint id) private billExists(id) {
        _bill_list[user].push(id);
    }

    function removeBillFromUser(address _user, uint id) private {
        if (_bills[id].owner == _user) {
            require(msg.sender == _user, ErrUnauthorized());
            setBillToNull(id);
        }

        uint j = 0;
        uint i = 0;
        for (; i < _bill_list[_user].length; i++) {
            if (_bill_list[_user][j] == id) {
                j++;
            }

            if (j > i && j < _bill_list[_user].length) {
                _bill_list[_user][i] == _bill_list[_user][j];
            }

            j++;
        }

        if (i != j) {
            _bill_list[_user].pop();
        }
    }

    // Create a bill
    function createBill(string calldata _title, uint _amount, uint _delta) public billNotExists(msg.sender, _title) {
        uint id = getNextId();
        _bills[id] = Bill({id: id, owner: msg.sender, title: _title, amount: _amount, remainder_index: 0, 
        delta: _delta, last_payment: 0, participants: new address[](0), requests: new address[](0), paused_participants: new address[](0)});

        addBillToUser(msg.sender, id);
    }

    // Get a bill
    function getBill(uint id) public view returns (Bill memory) {
        Bill memory b = _bills[id];
        assert(!isBillNull(b));

        return b;
    }

    function getBillByOwnerAndTitle(address _bill_owner, string calldata _title) public view returns (Bill memory) {
        for (uint i = 0; i < _bill_list[_bill_owner].length; i++) {
            if (areStringsEqual(_bills[_bill_list[_bill_owner][i]].title, _title)) {
                return _bills[_bill_list[_bill_owner][i]];
            }
        }

        revert ErrBillDoesNotExist();
    }

    // Get bills
    function getBills(address user) public view returns (Bill[] memory) {
        if (_bill_list[user].length == 0) {
            return new Bill[](0);
        }

        Bill[] memory bills = new Bill[](_bill_list[user].length);
        for (uint i = 0; i < _bill_list[user].length; i++) {
            bills[i] = _bills[_bill_list[user][i]];
        }

        return bills;
    }

    /* Participant Interactions */

    // Request to join a bill. Reverts if the sender is already a participant or has a pending request.
    function requestToJoin(address _bill_owner, string calldata _title) public {
        // Check that this address is not already a participant, or has a pending request
        Bill memory bill = getBillByOwnerAndTitle(_bill_owner, _title);
        for (uint i = 0; i < bill.participants.length; i++) {
            if (bill.participants[i] == msg.sender) {
                revert ErrAlreadyParticipant();
            }
        }

        for (uint i = 0; i < bill.requests.length; i++) {
            if (bill.requests[i] == msg.sender) {
                revert ErrPendingRequest();
            }
        }

        // Make request
        _bills[bill.id].requests.push(msg.sender);
        _request_count[msg.sender]++;
        addBillToUser(msg.sender, bill.id);
    }

    // Generic request cancellation
    function cancelRequest(address _bill_owner, string calldata _title, address _requester, bool _accepted) private {
        Bill memory bill = getBillByOwnerAndTitle(_bill_owner, _title);

        for (uint i = 0; i < bill.requests.length; i++) {
            if (bill.requests[i] == _requester) {
                for (uint j = i + 1; j < bill.requests.length; j++) {
                    _bills[bill.id].requests[j-1] = _bills[bill.id].requests[j];
                }
                _bills[bill.id].requests.pop();
                _request_count[_requester]--;
            }
        }

        if (!_accepted) {
            removeBillFromUser(_requester, bill.id);
        }
    }

    // Cancel request to join. Returns true if request was successfully cancelled, and false
    // if the request did not exist.
    function cancelRequestToJoin(address _bill_owner, string calldata _title) public {
        cancelRequest(_bill_owner, _title, msg.sender, false);
    }

    // Cancel request to join. Returns true if request was successfully cancelled, and false
    // if the request did not exist.
    function declineRequestToJoin(address _requester, string calldata _title) public {
        cancelRequest(msg.sender, _title, _requester, false);
    }

    // Get all pending requests
    function getPendingRequests() public view returns(Bill[] memory) {
        Bill[] memory bills = new Bill[](_request_count[msg.sender]);
        uint insert = 0;
        for (uint i = 0; i < _bill_list[msg.sender].length; i++) {
            for (uint j = 0; j < _bills[_bill_list[msg.sender][i]].requests.length; j++) {
                if (msg.sender == _bills[_bill_list[msg.sender][i]].requests[j]) {
                    bills[insert] = _bills[_bill_list[msg.sender][i]];
                    insert++;
                }
            }
        }
        return bills;
    }

    function acceptRequest(string calldata _title, address _requester) public {
        // Get the bill
        Bill memory b = getBillByOwnerAndTitle(msg.sender, _title);

        for (uint i = 0; i < b.requests.length; i++) {
            if (b.requests[i] == _requester) {
                // Add bill
                _bills[b.id].participants.push(_requester);

                // Remove the request
                cancelRequest(msg.sender, _title, _requester, true);
            }
        }
    }

    // Pause bill payments
    function pause(address _bill_owner, string calldata _title) public {
        Bill memory bill = getBillByOwnerAndTitle(_bill_owner, _title);
        uint i = 0;
        for (; i < bill.paused_participants.length; i++) {
            if (bill.paused_participants[i] == msg.sender) {
                break;
            }
        }

        if (i == bill.paused_participants.length) {
            _bills[bill.id].paused_participants.push(msg.sender);
        }
    }

    function unpause(address _bill_owner, string calldata _title) public {
        Bill memory bill = getBillByOwnerAndTitle(_bill_owner, _title);
        uint i = 0;
        uint j = 0;
        for (; i < _bills[bill.id].paused_participants.length; i++) {
            if (bill.paused_participants[i] == msg.sender) {
                j++;
            }

            if (j > i && j < _bills[bill.id].paused_participants.length) {
                _bills[bill.id].paused_participants[i] = _bills[bill.id].paused_participants[j];
            }

            j++;
        }

        if (j != i) {
            _bills[bill.id].paused_participants.pop();
        }
    }

    function isPaused(address _bill_owner, string calldata _title, address _participant) public view returns(bool) {
        Bill memory bill = getBillByOwnerAndTitle(_bill_owner, _title);
        for (uint i = 0; i < bill.paused_participants.length; i++) {
            if (bill.paused_participants[i] == _participant) {
                return true;
            }
        }

        return false;
    }

    // Removal from bill
    function exitBill(address _bill_owner, string calldata _title, address _participant) private {
        Bill memory b = getBillByOwnerAndTitle(_bill_owner, _title);

        uint j = 0;
        uint i = 0;
        for (; i < b.participants.length; i++) {
            if (b.participants[i] == _participant) {
                j++;
            }

            if (i < j && j < b.participants.length) {
                _bills[b.id].participants[i] = _bills[b.id].participants[j];
            }

            j++;
        }

        if (i != j) {
            _bills[b.id].participants.pop();

            // Pause all participants. Since each participant will need
            // to pay more when a someone leaves, they should opt
            // back in by unpausing themselves.
            _bills[b.id].paused_participants = new address[](_bills[b.id].participants.length);
            for (uint k = 0; k < _bills[b.id].participants.length; k++) {
                _bills[b.id].paused_participants[k] = _bills[b.id].participants[k]; 
            }
        }

        // Remove from bill list
        removeBillFromUser(msg.sender, b.id);
    }

    function leave(address _bill_owner, string calldata _title) public {
        exitBill(_bill_owner, _title, msg.sender);
    }

    function removeParticipant(address _participant, string calldata _title) public {
        exitBill(msg.sender, _title, _participant);
    }
    
    // Participant deposit and withdraw funds
    function deposit() public payable {
        _balances[msg.sender] += msg.value;
    }

    function balance() public view returns(uint) {
        return _balances[msg.sender];
    }

    function withdraw(uint amount) public payable {
        assert(_balances[msg.sender] >= amount && address(this).balance >= amount);
        _balances[msg.sender] -= amount;

        payable(msg.sender).transfer(amount);
    }

    // Bill owner accepts payment for a bill
    function acceptPayment(string calldata _title) public payable {
        Bill memory b = getBillByOwnerAndTitle(msg.sender, _title);
        assert(b.owner == msg.sender);
        assert(b.participants.length > 0);
        assert(b.last_payment == 0 || (b.last_payment != 0 && block.timestamp - b.last_payment >= b.delta));

        uint amount_payable = b.amount / (b.participants.length + 1);
        uint remainder = b.amount % (b.participants.length + 1);

        uint i = b.remainder_index;
        uint stop;
        if (i >= b.participants.length + 1) {
            i = 0;
        }
        stop = i;

        do {
            uint rem = 0;
            if (remainder > 0) {
                rem = 1;
                remainder--;
            } else if (remainder == 0) {
                b.remainder_index = i;
            }

            // Only send money if we are not accounting for the owner's share
            if (i != b.participants.length) {
                require(!isPaused(b.owner, _title, b.participants[i]));
                require(_balances[b.participants[i]] >= amount_payable + rem);

                _balances[b.participants[i]] -= amount_payable + rem;
                _balances[b.owner] += amount_payable + rem;
            } else {
                require(b.owner.balance >= amount_payable + rem);
            }

            i = (i + 1) % (b.participants.length + 1);
        } while (i != stop);

        // Save changes to bill
        b.last_payment = block.timestamp;
        _bills[b.id] = b;
    }
}