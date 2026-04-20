USE Destinos_Soñados_SA; # Utilizar Base de Datos Creada
SET GLOBAL event_scheduler = ON;

# 1.	EVT_VerificarConfirmacionesPendientes: Verifica reservas que requieren confirmación.
DELIMITER //
CREATE EVENT EVT_VerificarConfirmacionesPendientes
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    UPDATE Reserva
    SET estado = 'Cancelada'
    WHERE estado = 'Pendiente'
    AND saldo_pendiente > 0
    AND fecha_creacion <= NOW() - INTERVAL 3 DAY;
END //
DELIMITER ;

#Basicamente busca los que tienen todavia estan en estado pendiente, si el cliente no ha abonado nada en un intervalo de 3 dias desde la fecha de creacion, le pone el estado de Cancelado
SELECT numero_reserva, estado, saldo_pendiente, fecha_creacion
FROM Reserva
WHERE estado = 'Cancelada';

#2.	EVT_ActualizarTarifasTemporada: Actualiza tarifas según temporada alta/baja.

#Recomiendo Ver primero los precios antes del evento
SELECT nombre_comercial, precio_base
FROM Paquete_Turistico ORDER BY nombre_comercial ASC;

DELIMITER //
CREATE EVENT EVT_ActualizarTarifasTemporada
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    -- Temporada alta
    UPDATE Paquete_Turistico
    SET precio_base = precio_base * 1.05
    WHERE MONTH(CURDATE()) IN (6,7,12);

    -- Temporada baja
    UPDATE Paquete_Turistico
    SET precio_base = precio_base * 0.98
    WHERE MONTH(CURDATE()) NOT IN (6,7,12);
END //
DELIMITER ;

# Cambia los multiplicadores del precio base dependiendo de la temporada en este caso Alta/Baja
SELECT nombre_comercial, precio_base
FROM Paquete_Turistico ORDER BY nombre_comercial ASC;

# 3.	EVT_GenerarReporteOcupacion: Genera reportes de ocupación por destino.

DELIMITER //
CREATE EVENT EVT_GenerarReporteOcupacion
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    CREATE TABLE IF NOT EXISTS Reporte_Ocupacion (
        id_reporte INT AUTO_INCREMENT PRIMARY KEY,
        fecha DATE,
        destino VARCHAR(150),
        total_reservas INT
    );

    INSERT INTO Reporte_Ocupacion (fecha, destino, total_reservas)
    SELECT 
        CURDATE(),
        d.nombre,
        COUNT(r.id_reserva)
    FROM Reserva r
    JOIN Paquete_Turistico p ON r.id_paquete = p.id_paquete
    JOIN Paquete_Destino pd ON p.id_paquete = pd.id_paquete
    JOIN Destino_Turistico d ON pd.id_destino = d.id_destino
    WHERE r.estado = 'Confirmada'
    GROUP BY d.nombre;
END //
DELIMITER ;
# Genera un resumen diario de reservas por destino creando una tabla nueva con esos datos

SELECT * FROM Reporte_Ocupacion ORDER BY destino ASC;

# 4.	EVT_NotificarSalidasProximas: Envía notificaciones de salidas programadas próximas.

DELIMITER //
CREATE EVENT EVT_NotificarSalidasProximas
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    CREATE TABLE IF NOT EXISTS Notificaciones (
        id_notificacion INT AUTO_INCREMENT PRIMARY KEY,
        mensaje TEXT,
        fecha DATETIME
    );

    INSERT INTO Notificaciones (mensaje, fecha)
    SELECT 
        CONCAT('Cliente ', c.nombres_razon_social, 
               ' tiene una reserva (', r.numero_reserva, ') que inicia pronto'),
        NOW()
    FROM Reserva r
    JOIN Cliente c ON r.id_cliente = c.id_cliente
    WHERE r.estado = 'Confirmada'
    AND r.fecha_inicio BETWEEN CURDATE() AND CURDATE() + INTERVAL 3 DAY;
END //
DELIMITER ;
# Detecta viajes que inician en 3 días y que solo esten en estado Confirmadas par mandar una notificacion
SELECT * FROM Notificaciones;

# 5.	EVT_ActualizarDisponibilidadPromocion: Actualiza la disponibilidad de plazas en promociones.
/* 
   En este evento toca agregar/modificar la tabla promocion agregando un nuevo campo que se llame estado tipo varchar porque asi podemos agregar las palabras Activo o Inactivo 
   dependiendo de cuando hay una promocion dentro de unas fechas establecidas
*/

ALTER TABLE Promocion 
ADD COLUMN estado VARCHAR(50);

DELIMITER //
CREATE EVENT EVT_ActualizarDisponibilidadPromocion
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    UPDATE Promocion
    SET estado = 'Activa'
    WHERE CURDATE() BETWEEN fecha_inicio AND fecha_fin;

    UPDATE Promocion
    SET estado = 'Inactiva'
    WHERE CURDATE() NOT BETWEEN fecha_inicio AND fecha_fin;
END //
DELIMITER ;
#Verificar
SELECT nombre, fecha_inicio, fecha_fin, estado
FROM Promocion;

