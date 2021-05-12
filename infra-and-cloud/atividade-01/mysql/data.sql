CREATE DATABASE IF NOT EXISTS vagrant;
USE vagrant
CREATE TABLE vagrant (id INT NOT NULL, nome VARCHAR(50) NOT NULL, curso VARCHAR(50) NOT NULL,PRIMARY KEY (id));
INSERT INTO vagrant (id,nome, curso) VALUES(1,'Rodrigo França','MBA - arquitetura de solucoes digitais');
SELECT * FROM vagrant;