dub fetch subdox

mkdir tmp-docs

for tag in `git tag -l | sort -V && echo master`
do
  rm -r $tag
  git checkout $tag
  dub build --build=ddox
  mkdir tmp-docs/$tag
  mv docs.json tmp-docs/$tag
  rm -r docs
  dub run subdox -- generate-html tmp-docs/$tag/docs.json tmp-docs/$tag
  cp README.md tmp-docs/$tag
  echo "- $tag" >> tmp-docs/versions.yml
done
rm __dummy.html

git checkout gh-pages
mv tmp-docs/versions.yml _data/versions.yml
mv tmp-docs/* .
rm -r tmp-docs/
git show master:README.md > _includes/README.md
git add -A
git commit -a -m "Updated automatically generated docs."
git checkout master
