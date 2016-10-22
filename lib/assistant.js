import {NativeModules} from 'react-native'
const _StorageAssistant = NativeModules.StorageAssistant

console.log(NativeModules);

function Assistant() {
  for (let path in _StorageAssistant) {
    let paths = path.split('_');
    if (paths.length < 2) { continue; }

    let domain = this[paths[0]] ? this[paths[0]] : (this[paths[0]] = {});
    domain[paths[1]] = function(... args) {
      _StorageAssistant[path].apply(_StorageAssistant, args);
    }
  }
}

Assistant.prototype = _StorageAssistant;

module.exports = new Assistant;

export default module.exports;