// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title FreelanceHub
 * @dev Plateforme de mise en relation de freelances avec un systeme de paiement par sequestre (escrow).
 */
contract FreelanceHub {
    
    // Definition du cycle de vie d'une commande
    // None: Annulee ou inexistante
    // Pending: En attente d'acceptation par le vendeur
    // Accepted: En cours de realisation par le vendeur
    // Delivered: Travail fourni, en attente de validation par l'acheteur
    // Completed: Travail valide, fonds transferes au vendeur
    enum OrderStatus { None, Pending, Accepted, Delivered, Completed }

    struct Service {
        uint id;
        address payable seller;
        string name;
        uint price; // Exprime en Wei pour la precision
        uint duration; // Exprime en jours
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

    // Indexation des evenements pour faciliter l'ecoute via le front-end
    event ServiceCreated(uint id, string name, address seller);
    event OrderPlaced(uint orderId, uint serviceId, address buyer);
    event OrderStatusChanged(uint orderId, OrderStatus newStatus);

    /**
     * @dev Permet a un vendeur de referencer une nouvelle prestation.
     */
    function createService(string memory _name, uint _priceInWei, uint _duration) public {
        require(bytes(_name).length > 0, "Le nom du service est requis");
        require(_priceInWei > 0, "Le prix doit etre superieur a zero");

        serviceCount++;
        services[serviceCount] = Service(serviceCount, payable(msg.sender), _name, _priceInWei, _duration, true);
        
        emit ServiceCreated(serviceCount, _name, msg.sender);
    }

    /**
     * @dev Permet a un acheteur de commander un service.
     * Les fonds sont conserves par le contrat (sequestre) jusqu'a la finalisation.
     */
    function buyService(uint _serviceId) public payable {
        Service storage _service = services[_serviceId];
        require(_service.id > 0 && _service.active, "Service inexistant ou marque comme inactif");
        require(msg.value == _service.price, "Le montant envoye ne correspond pas au prix du service");

        orderCount++;
        // L'acheteur est stocke en tant qu'adresse pour permettre un remboursement en cas de refus
        orders[orderCount] = Order(orderCount, _serviceId, msg.sender, _service.seller, msg.value, OrderStatus.Pending);
        
        emit OrderPlaced(orderCount, _serviceId, msg.sender);
    }

    /**
     * @dev Permet au vendeur d'accepter ou de refuser une commande entrante.
     * En cas de refus, les fonds sont immediatement restitues a l'acheteur.
     */
    function respondToOrder(uint _orderId, bool _accept) public {
        Order storage _order = orders[_orderId];
        require(msg.sender == _order.seller, "Autorisation refusee : Vendeur uniquement");
        require(_order.status == OrderStatus.Pending, "La commande n'est pas en attente d'une reponse");

        if (_accept) {
            _order.status = OrderStatus.Accepted;
        } else {
            _order.status = OrderStatus.None;
            payable(_order.buyer).transfer(_order.amount);
        }
        
        emit OrderStatusChanged(_orderId, _order.status);
    }

    /**
     * @dev Permet au vendeur de signaler que le travail a ete fourni.
     * Cette etape est necessaire pour que l'acheteur puisse proceder a la validation finale.
     */
    function deliverOrder(uint _orderId) public {
        Order storage _order = orders[_orderId];
        require(msg.sender == _order.seller, "Autorisation refusee : Vendeur uniquement");
        require(_order.status == OrderStatus.Accepted, "La commande doit etre au statut 'Acceptee' pour etre livree");

        _order.status = OrderStatus.Delivered;
        
        emit OrderStatusChanged(_orderId, _order.status);
    }

    /**
     * @dev Permet a l'acheteur de valider la conformite du travail.
     * Declenche la liberation des fonds du sequestre vers le portefeuille du vendeur.
     */
    function completeOrder(uint _orderId) public {
        Order storage _order = orders[_orderId];
        require(msg.sender == _order.buyer, "Autorisation refusee : Acheteur uniquement");
        require(_order.status == OrderStatus.Delivered, "Le vendeur n'a pas encore livre la commande");

        _order.status = OrderStatus.Completed;
        _order.seller.transfer(services[_order.serviceId].price);
        
        emit OrderStatusChanged(_orderId, _order.status);
    }
}