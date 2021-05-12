CREATE DATABASE IF NOT EXISTS mbaimpacta;
CREATE TABLE mbaimpacta (id INT NOT NULL, nome VARCHAR(50) NOT NULL, curso VARCHAR(50) NOT NULL,PRIMARY KEY (id));
INSERT INTO mbaimpacta (id,nome, curso) VALUES(1,'Rodrigo França','MBA - arquitetura de solucoes digitais');
SELECT * FROM mbaimpacta;