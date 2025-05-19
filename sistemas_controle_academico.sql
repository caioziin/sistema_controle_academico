 -- ALUNP + TURMA + DISCIPLINA + PROFESSOR

select a.nome as aluno, t.semestre, d.nome as disciplina,p.nome as professor 
from alunos a
inner join matriculas m on a.id = m.alunos_id
inner join turmas t on m.turmas_id = t.id	
inner join disciplinas d on t.disciplinas_id = d.id
inner join professores p on t.professores_id = p.id;

-- ALUNOS MESMO SEM NOTA LANÇADA

select a.nome as aluno, n.avaliacao, n.nota
from alunos a 
left join matriculas m on a.id = m.alunos_id
left join notas n on m.id = n.matricula_id;

-- PRESENÇAS MESMO SEM VINCULOS COM OS ALUNOS

select a.nome as aluno, pr.date_aula, pr.presente
from alunos a
right join matriculas m on a.id = m.alunos_id
right join presencas pr on m.id = pr.matricula_id;

-- TODOS ALUNOS E TODAS AS MATRICULAS

select a.nome as aluno, m.turmas_id, m.data_matricula
from alunos a
full join matriculas m on a.id = m.alunos_id;


-- MEDIA DE NOTAS POR ALUNO

select a.nome as aluno, medias.media_geral
from alunos a
inner join (
	select m.alunos_id, avg(n.nota) as media_geral
	from matriculas m
	join notas n on m.id = n.matricula_id
	group by m.alunos_id
) as medias on a.id = medias.alunos_id;

-- VIZUALIZAR OS JOINS

select 
  a.nome as aluno, 
  d.nome as disciplina,
  t.semestre,
  m.data_matricula,
  n.avaliacao,
  n.nota
from alunos a
join matriculas m on a.id = m.alunos_id
join turmas t on m.turmas_id = t.id
join disciplinas d on t.disciplinas_id = d.id
left join notas n on m.id = n.matricula_id;

--PROCEDURE

create or replace procedure listar_alunos()
language plpgsql
as $$
declare
	a record;
	c cursor for select nome from alunos;
begin
	open c;
	loop
		fetch c into a;
		exit when not found;
		raise notice 'Aluno: %', a.nome;
	end loop;
	close c;
end;
$$;

call listar_alunos();

select * from alunos;

create or replace procedure cadastrar_professor(
	p_nome varchar,
	p_email varchar default null
)
language plpgsql
as $$
begin 
	insert into professores(nome,email)
	values (p_nome,p_email);
end;
$$;

call cadastrar_professor('Aramis Neto', 'aramis.neto@uniesp.com');

select * from professores;

-- FUNÇÔES

create or replace function calcular_idade(p_data date)
returns int
language plpgsql
as $$
declare
    v_idade int;
begin
    v_idade := date_part('year', age(p_data));
    return v_idade;
end;
$$;

select calcular_idade('2003-04-14');


create or replace function alunos_maiores_de(p_idade int)
returns table(id int, nome varchar, idade int)
language plpgsql
as $$
begin
    return query
    select a.id, a.nome, calcular_idade(a.data_nascimento) as idade
    from alunos a
    where calcular_idade(a.data_nascimento) > p_idade;
end;
$$;

select * from alunos_maiores_de(18);

create or replace function dividir_notas(p_nota1 numeric, p_nota2 numeric)
returns numeric
language plpgsql
as $$
begin
    if p_nota2 = 0 then
        raise exception 'Divisão por zero não é permitida.';
    end if;
    return p_nota1 / p_nota2;
end;
$$;

select dividir_notas(8.5, 0); -- Vai gerar erro com mensagem


-- TRIGGER

create table log_alteracoes_alunos (
    id serial primary key,
    aluno_id int,
    nome_antigo varchar,
    nome_novo varchar,
    data_alteracao timestamp default current_timestamp
);

create or replace function auditar_aluno()
returns trigger
language plpgsql
as $$
begin
    if new.nome is distinct from old.nome then
        insert into log_alteracoes_alunos(aluno_id, nome_antigo, nome_novo)
        values (old.id, old.nome, new.nome);
    end if;
    return new;
end;
$$;

create trigger trg_auditar_aluno
before update on alunos
for each row
execute function auditar_aluno();

create or replace function inserir_presenca_padrao()
returns trigger
language plpgsql 
as $$
begin 
	insert into presencas(matricula_id, date_aula,presente)
	values (new.id,currrent_date, false);
	return new;
end;
$$;

create trigger 	trg_inserir_presenca
after insert on matriculas
for each row 
execute function inserir_presenca_padrao();

create or replace function bloquear_email_professor()
returns trigger
language plpgsql
as $$ 
begin 
	if new.email is distinct from old.email then 
		raise exception 'Atualização de email de professor nao é permitida';
	end if;
	return new;
end;
$$;

create trigger trg_bloquear_email
before update on professores
for each row
execute function bloquear_email_professor(); 


--INDEXACAO

create index idx_alunos_nome on alunos(nome);

create index idx_matriculas_data on matriculas (data_matricula);


create index idx_turmas_disciplinas_semestre on turmas(disciplinas_id, semestre);

explain analyze 
select a.nome, d.nome as disciplina, t.semestre, m.data_matricula
from alunos a
join matriculas m on a.id = m.alunos_id
join turmas t on m.turmas_id = t.id
join disciplinas d on t.disciplinas_id = d.id
where a.nome ilike '%Pedro'
and t.semestre = '2025.1';

-- Índice no nome do aluno (já criado acima) e no semestre:
create index idx_turmas_semestre on turmas(semestre);

-- Rode novamente:
explain analyze
select a.nome, d.nome as disciplina, t.semestre, m.data_matricula
from alunos a
join matriculas m on a.id = m.alunos_id
join turmas t on m.turmas_id = t.id
join disciplinas d on t.disciplinas_id = d.id
where a.nome ilike '%Pedro%'
and t.semestre = '2025.1';


-- Habilitar extensão para buscas mais rápidas com LIKE:
create extension if not exists pg_trgm;

-- Criar índice GIN para melhorar buscas com ILIKE
create index idx_alunos_nome_trgm on alunos using gin (nome gin_trgm_ops);


