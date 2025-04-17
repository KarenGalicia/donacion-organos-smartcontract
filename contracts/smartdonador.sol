// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.0/contracts/access/AccessControl.sol";

contract DonacionOrganos is AccessControl {
    bytes32 public constant HOSPITAL_ROLE = keccak256("HOSPITAL_ROLE");
    bytes32 public constant MEDICO_ROLE = keccak256("MEDICO_ROLE");
    bytes32 public constant FAMILIAR_ROLE = keccak256("FAMILIAR_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        cabeza = 0;
        contadorTransacciones = 0;
    }

    address[] public listaDonantes;
    address[] public cuentasConRol;

    struct Donante {
        string nombre;
        string tipoSangre;
        string[] organos;
        bool registrado;
    }

    struct Receptor {
        string nombre;
        string tipoSangre;
        string organoNecesitado;
        bool registrado;
    }

    struct NodoTransaccion {
        uint id;
        address de;
        address para;
        string organo;
        uint256 timestamp;
        uint siguiente;
    }

    mapping(address => Donante) public donantes;
    mapping(address => Receptor) public receptores;

    mapping(uint => NodoTransaccion) public transacciones;
    mapping(address => uint[]) public historialPorDireccion;
    uint public cabeza;
    uint public contadorTransacciones;

    event DonanteRegistrado(address indexed cuenta, string nombre);
    event ReceptorRegistrado(address indexed cuenta, string nombre);
    event RolRevocado(address indexed cuenta, string rol);

    function asignarHospital(address cuenta) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(HOSPITAL_ROLE, cuenta);
        cuentasConRol.push(cuenta);
    }

    function asignarMedico(address cuenta) public onlyRole(HOSPITAL_ROLE) {
        grantRole(MEDICO_ROLE, cuenta);
        cuentasConRol.push(cuenta);
    }

    function asignarFamiliar(address cuenta) public onlyRole(HOSPITAL_ROLE) {
        grantRole(FAMILIAR_ROLE, cuenta);
        cuentasConRol.push(cuenta);
    }

    function revocarRol(address cuenta, bytes32 rol) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(rol, cuenta), "La cuenta no tiene ese rol");
        revokeRole(rol, cuenta);
        emit RolRevocado(cuenta, nombreRol(rol));
    }

    function nombreRol(bytes32 rol) internal pure returns (string memory) {
        if (rol == HOSPITAL_ROLE) return "Hospital";
        if (rol == MEDICO_ROLE) return "Medico";
        if (rol == FAMILIAR_ROLE) return "Familiar";
        return "Desconocido";
    }

    function registrarDonante(
        string memory _nombre,
        string memory _tipoSangre,
        string[] memory _organos
    ) public onlyRole(HOSPITAL_ROLE) {
        require(!donantes[msg.sender].registrado, "Ya estas registrado como donante.");
        donantes[msg.sender] = Donante(_nombre, _tipoSangre, _organos, true);
        listaDonantes.push(msg.sender);
        emit DonanteRegistrado(msg.sender, _nombre);
    }

    function registrarReceptor(
        string memory _nombre,
        string memory _tipoSangre,
        string memory _organoNecesitado
    ) public onlyRole(HOSPITAL_ROLE) {
        require(!receptores[msg.sender].registrado, "Ya estas registrado como receptor.");
        receptores[msg.sender] = Receptor(_nombre, _tipoSangre, _organoNecesitado, true);
        emit ReceptorRegistrado(msg.sender, _nombre);
    }

    function transferirOrgano(address receptor, string memory organo) public onlyRole(HOSPITAL_ROLE) {
        require(donantes[msg.sender].registrado, "El donante no esta registrado.");
        require(receptores[receptor].registrado, "El receptor no esta registrado.");

        bool encontrado = false;
        string[] storage organos = donantes[msg.sender].organos;

        for (uint i = 0; i < organos.length; i++) {
            if (keccak256(bytes(organos[i])) == keccak256(bytes(organo))) {
                organos[i] = organos[organos.length - 1];
                organos.pop();
                encontrado = true;
                break;
            }
        }

        require(encontrado, "El organo no esta disponible.");

        NodoTransaccion memory nueva = NodoTransaccion({
            id: contadorTransacciones,
            de: msg.sender,
            para: receptor,
            organo: organo,
            timestamp: block.timestamp,
            siguiente: cabeza
        });

        transacciones[contadorTransacciones] = nueva;
        cabeza = contadorTransacciones;
        historialPorDireccion[msg.sender].push(contadorTransacciones);
        historialPorDireccion[receptor].push(contadorTransacciones);
        contadorTransacciones++;
    }

    function obtenerHistorial(address usuario) public view returns (NodoTransaccion[] memory) {
        uint[] memory indices = historialPorDireccion[usuario];
        NodoTransaccion[] memory resultado = new NodoTransaccion[](indices.length);

        for (uint i = 0; i < indices.length; i++) {
            resultado[i] = transacciones[indices[i]];
        }

        return resultado;
    }

    function getOrganosDisponibles(address donante) public view returns (string[] memory) {
        require(donantes[donante].registrado, "Donante no registrado");
        return donantes[donante].organos;
    }

    function tieneRol(address cuenta, bytes32 rol) public view returns (bool) {
        return hasRole(rol, cuenta);
    }

    function listarCuentasConRol(bytes32 rol) public view returns (address[] memory) {
        uint count = 0;
        for (uint i = 0; i < cuentasConRol.length; i++) {
            if (hasRole(rol, cuentasConRol[i])) {
                count++;
            }
        }
        address[] memory resultado = new address[](count);
        uint index = 0;
        for (uint i = 0; i < cuentasConRol.length; i++) {
            if (hasRole(rol, cuentasConRol[i])) {
                resultado[index] = cuentasConRol[i];
                index++;
            }
        }
        return resultado;
    }
}
