
python bootstrap.pyc role -a 

hosts=(Angryman-portal-01.cloudena.com Angryman-backup-01.cloudena.com Angryman-identity-01.cloudena.com Angryman-monitor-01.cloudena.com Angryman-policy-01.cloudena.com)

for i in {0..4}
do
echo ${hosts[i]}
python bootstrap.pyc os -r ${hosts[i]}
done
#python bootstrap.pyc os -r 
