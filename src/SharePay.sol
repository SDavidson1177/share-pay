// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SharePay is OwnableUpgradeable {
    struct Bill {
        address owner;
        string title;
        uint amount;
        uint remainder_index;
        uint delta;
        uint last_payment;
        address[] participants;
        address[] requests;
    }

    struct BillIndex {
        address owner;
        string title;
    }

    struct BillResponse {
        Bill bill;
        bool paused;
        address[] all_paused;
    }

    address private _owner;
    mapping(address => mapping(string => Bill)) private _bills;
    mapping(address => uint) private _balances;
    mapping(address => mapping(string => mapping(address => bool))) private _paused;
    mapping(address => BillIndex[]) private _bill_list;
    mapping(address => BillIndex[]) private _pending_requests;

    constructor() initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);
    }

    function initialize() public initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);
    }

    receive() external payable {
        deposit();
    }

    modifier billExists(address _bill_owner, string memory _title) {
        Bill memory b = _bills[_bill_owner][_title];
        assert(!isBillNull(b));

        _;
    }

    function areStringsEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    /* Bill Manipulations */

    // Create a null bill
    function nullBill() public view returns (Bill memory) {
        return Bill(msg.sender, "", 0, 0, 0, 0, new address[](0), new address[](0));
    }

    // Check if a bill is null
    function isBillNull(Bill memory b) public pure returns(bool) {
        return b.amount == 0;
    }

    // Create a bill
    function createBill(string memory _title, uint _amount, uint _delta) public {
        _bills[msg.sender][_title] = Bill({owner: msg.sender, title: _title, amount: _amount, remainder_index: 0, 
        delta: _delta, last_payment: 0, participants: new address[](0), requests: new address[](0)});
        _bill_list[msg.sender].push(BillIndex(msg.sender, _title));
    }

    // Get a bill
    function getBill(address _bill_owner, string memory _title) public view returns (Bill memory) {
        Bill memory b = _bills[_bill_owner][_title];
        assert(!isBillNull(b));

        return b;
    }

    // Get bills
    function getBills(address user) public view returns (BillResponse[] memory) {
        if (_bill_list[user].length == 0) {
            return new BillResponse[](0);
        }

        BillResponse[] memory bills = new BillResponse[](_bill_list[user].length);
        for (uint i = 0; i < _bill_list[user].length; i++) {
            // find all paused
            Bill memory b = _bills[_bill_list[user][i].owner][_bill_list[user][i].title];
            address[] memory all_paused = new address[](b.participants.length);
            bool paused = false;
            for (uint j = 0; j < b.participants.length; j++) {
                if ( _paused[_bill_list[user][i].owner][_bill_list[user][i].title][b.participants[j]]) {
                    all_paused[j] = b.participants[j];
                    paused = true;
                }
            }

            bills[i] = BillResponse(b, paused, all_paused);
        }

        return bills;
    }

    /* Participant Interactions */

    // Request to join a bill. Returns true if a new request waw submitted, and false if the sender is already a participant
    // or has a pending request.
    function requestToJoin(address _bill_owner, string memory _title) public billExists(_bill_owner, _title) returns(bool) {
        // Check that this address is not already a participant, or has a pending request
        for (uint i = 0; i < _bills[_bill_owner][_title].participants.length; i++) {
            if (_bills[_bill_owner][_title].participants[i] == msg.sender) {
                return false;
            }
        }

        for (uint i = 0; i < _pending_requests[msg.sender].length; i++) {
            if (_pending_requests[msg.sender][i].owner == _bill_owner &&
                areStringsEqual(_pending_requests[msg.sender][i].title, _title)) {
                return false;
            }
        }

        _bills[_bill_owner][_title].requests.push(msg.sender);
        _pending_requests[msg.sender].push(BillIndex(_bill_owner, _title));
        return true;
    }

    // Generric request cancellation
    function cancelRequest(address _bill_owner, string memory _title, address _requester) private returns(bool) {
        uint16 cancellations = 0;

        for (uint i = 0; i < _bills[_bill_owner][_title].requests.length; i++) {
            if (_bills[_bill_owner][_title].requests[i] == _requester) {
                cancellations++;
                for (uint j = i + 1; j < _bills[_bill_owner][_title].requests.length; j++) {
                    _bills[_bill_owner][_title].requests[j-1] = _bills[_bill_owner][_title].requests[j];
                }
                _bills[_bill_owner][_title].requests.pop();
            }
        }

        for (uint i = 0; i < _pending_requests[_requester].length; i++) {
            if (_pending_requests[_requester][i].owner == _bill_owner && 
            areStringsEqual(_pending_requests[_requester][i].title, _title)) {
                cancellations++;
                for (uint j = i + 1; j < _pending_requests[_requester].length; j++) {
                    _pending_requests[_requester][j-1] = _pending_requests[_requester][j];
                }
                _pending_requests[_requester].pop();
            }
        }

        assert(cancellations == 2);
        return true;
    }

    // Cancel request to join. Returns true if request was successfully cancelled, and false
    // if the request did not exist.
    function cancelRequestToJoin(address _bill_owner, string memory _title) public billExists(_bill_owner, _title) returns(bool) {
        return cancelRequest(_bill_owner, _title, msg.sender);
    }

    // Cancel request to join. Returns true if request was successfully cancelled, and false
    // if the request did not exist.
    function declineRequestToJoin(address _requester, string memory _title) public billExists(msg.sender, _title) returns(bool) {
        return cancelRequest(msg.sender, _title, _requester);
    }

    // Get all pending requests
    function getPendingRequests() public view returns(BillIndex[] memory) {
        return _pending_requests[msg.sender];
    }

    function acceptRequest(string memory _title, address requester) public {
        // Get the bill
        Bill memory b = getBill(msg.sender, _title);

        for (uint i = 0; i < b.requests.length; i++) {
            if (b.requests[i] == requester) {
                // Add bill
                _bills[msg.sender][_title].participants.push(requester);
                _bill_list[requester].push(BillIndex(msg.sender, _title));

                // Remove the request
                cancelRequest(msg.sender, _title, requester);
            }
        }
    }

    // Pause bill payments
    function pause(address _bill_owner, string memory _title) public {
        _paused[_bill_owner][_title][msg.sender] = true;
    }

    function unpause(address _bill_owner, string memory _title) public {
        _paused[_bill_owner][_title][msg.sender] = false;
    }

    function isPaused(address _bill_owner, string memory _title, address participant) public view returns(bool) {
        return _paused[_bill_owner][_title][participant];
    }

    // Removal from bill
    function exitBill(address _bill_owner, string memory _title, address _participant) private returns(bool) {
        Bill memory b = getBill(_bill_owner, _title);

        uint j = 0;
        uint i = 0;
        for (; i < b.participants.length; i++) {
            if (b.participants[i] == _participant) {
                j = i + 1;
            } else {
                // Pause all participants. Since each participant will need
                // to pay more when a someone leaves, they should opt
                // back in by unpausing themselves.
                _paused[_bill_owner][_title][b.participants[i]] = true;
            }

            if (i < j && j < b.participants.length) {
                _bills[_bill_owner][_title].participants[i] = _bills[_bill_owner][_title].participants[j];
            }

            j++;
        }

        if (i == j) {
            return false;
        }

        // Remove from bill list
        j = 0;
        i = 0;
        for (; j < _bill_list[_participant].length; i++) {
            if (_bill_list[_participant][i].owner == _bill_owner && areStringsEqual(_bill_list[_participant][i].title, _title)) {
                j++;
                if (j >= _bill_list[_participant].length) {
                    break;
                }
            }

            if (i != j) {
                _bill_list[_participant][i] = _bill_list[_participant][j];
            }

            j++;
        }

        _bills[_bill_owner][_title].participants.pop();
        _bill_list[_participant].pop();
        return true;
    }

    function leave(address _bill_owner, string memory _title) public returns(bool) {
        return exitBill(_bill_owner, _title, msg.sender);
    }

    function removeParticipant(address _participant, string memory _title) public returns(bool) {
        return exitBill(msg.sender, _title, _participant);
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
    function acceptPayment(string memory _title) public payable {
        Bill memory b = getBill(msg.sender, _title);
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
                assert(!isPaused(b.owner, _title, b.participants[i]));
                assert(_balances[b.participants[i]] >= amount_payable + rem);

                _balances[b.participants[i]] -= amount_payable + rem;
                _balances[b.owner] += amount_payable + rem;
            } else {
                assert(b.owner.balance >= amount_payable + rem);
            }

            i = (i + 1) % (b.participants.length + 1);
        } while (i != stop);

        // Save changes to bill
        b.last_payment = block.timestamp;
        _bills[msg.sender][_title] = b;
    }
}