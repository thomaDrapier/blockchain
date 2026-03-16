// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FreelanceHub {
    
    enum OrderStatus { None, Pending, Accepted, Completed }

    struct Service {
        uint id;
        address payable seller;
        string name;
        uint price; // en eth
        uint duration; // en jours
        bool active;
    }

    struct Order {
        uint id;
        uint serviceId;
        address buyer;
        address payable seller;
        uint amount;
        OrderStatus status;
    }

    uint public serviceCount = 0;
    uint public orderCount = 0;

    mapping(uint => Service) public services;
    mapping(uint => Order) public orders;

    // Événements pour les "Messages" (Notifications Frontend)
    event ServiceCreated(uint id, string name, address seller);
    event OrderPlaced(uint orderId, uint serviceId, address buyer);
    event OrderStatusChanged(uint orderId, OrderStatus newStatus);

    // --- LES FONCTIONS ---

    // 1. Créer un service (Section : Services enregistrés)
    function createService(string memory _name, uint _priceInEth, uint _duration) public {
        require(bytes(_name).length > 0, "Le nom est requis");
        require(_priceInEth > 0, "Le prix doit etre superieur a 0");

        serviceCount++;
        services[serviceCount] = Service(serviceCount, payable(msg.sender), _name, _priceInEth, _duration, true);
        
        emit ServiceCreated(serviceCount, _name, msg.sender);
    }

    // 2. Acheter un service (Section : Acheter des services)
    // L'argent est envoyé ici et reste bloqué sur le contrat
    function buyService(uint _serviceId) public payable {
        Service storage _service = services[_serviceId];
        
        require(_service.id > 0 && _service.active, "Service inexistant ou inactif");
        require(msg.value == _service.price, "Veuillez envoyer le montant exact");
        require(msg.sender != _service.seller, "Vous ne pouvez pas acheter votre propre service");

        orderCount++;
        // On enregistre la commande avec l'acheteur payable pour un potentiel remboursement
        orders[orderCount] = Order(orderCount, _serviceId, payable(msg.sender), _service.seller, msg.value, OrderStatus.Pending);
        
        emit OrderPlaced(orderCount, _serviceId, msg.sender);
    }

    // 3. Accepter ou Refuser (Section : Messages)
    function respondToOrder(uint _orderId, bool _accept) public {
        Order storage _order = orders[_orderId];
        
        require(msg.sender == _order.seller, "Seul le vendeur peut repondre");
        require(_order.status == OrderStatus.Pending, "Statut invalide");

        if (_accept) {
            _order.status = OrderStatus.Accepted;
        } else {
            // Remboursement immédiat si le vendeur refuse
            _order.status = OrderStatus.None;
            payable(_order.buyer).transfer(_order.amount); // On renvoie l'argent à l'acheteur
        }
        
        emit OrderStatusChanged(_orderId, _order.status);
    }

    // 4. Valider le travail (Section : Travail en cours)
    function completeOrder(uint _orderId) public {
        Order storage _order = orders[_orderId];
        
        require(msg.sender == _order.buyer, "Seul l'acheteur peut valider");
        require(_order.status == OrderStatus.Accepted, "Le travail n'est pas en cours");

        _order.status = OrderStatus.Completed;
        
        // Transfert final de l'argent du contrat vers le vendeur
        _order.seller.transfer(services[_order.serviceId].price);
        
        emit OrderStatusChanged(_orderId, _order.status);
    }
}