#!/usr/bin/env python3
"""Generate the dependency-free universal Xcode project from checked-in sources."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'Herbert.xcodeproj'
PROJECT.mkdir(exist_ok=True)
objects = {}


def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def obj(key_name, isa, **values):
    key = uid(key_name)
    objects[key] = {'isa': isa, **values}
    return key


def quote(value):
    return json.dumps(str(value), ensure_ascii=False)


def render(value, indent=0):
    if isinstance(value, dict):
        return '{\n' + ''.join('\t' * (indent + 1) + quote(k) + ' = ' + render(v, indent + 1) + ';\n' for k, v in value.items()) + '\t' * indent + '}'
    if isinstance(value, list):
        return '(' + ', '.join(render(v, indent) for v in value) + ')'
    return quote(value)


project_id = uid('project')
app_id = uid('app')
test_id = uid('uitests')
store_id = uid('app-store')
store_test_id = uid('app-store-uitests')
package = obj('local-package', 'XCLocalSwiftPackageReference', relativePath='.')
product = obj('core-product', 'XCSwiftPackageProductDependency', productName='HerbertCore')
framework = obj('core-link', 'PBXBuildFile', productRef=product)
battlefield_product = obj('battlefield-product', 'XCSwiftPackageProductDependency', productName='HerbertBattlefield')
battlefield_framework = obj('battlefield-link', 'PBXBuildFile', productRef=battlefield_product)
community_product = obj('community-product', 'XCSwiftPackageProductDependency', productName='HerbertCommunity')
community_framework = obj('community-link', 'PBXBuildFile', productRef=community_product)
app_product = obj('app-product', 'PBXFileReference', explicitFileType='wrapper.application', path='Herbert.app', sourceTree='BUILT_PRODUCTS_DIR')
test_product = obj('test-product', 'PBXFileReference', explicitFileType='wrapper.cfbundle', path='HerbertUITests.xctest', sourceTree='BUILT_PRODUCTS_DIR')
store_product = obj('store-product', 'PBXFileReference', explicitFileType='wrapper.application', path='HerbertAppStore.app', sourceTree='BUILT_PRODUCTS_DIR')
store_test_product = obj('store-test-product', 'PBXFileReference', explicitFileType='wrapper.cfbundle', path='HerbertAppStoreUITests.xctest', sourceTree='BUILT_PRODUCTS_DIR')
app_files, app_sources, resources = [], [], []
for path in sorted((ROOT / 'Herbert').rglob('*.swift')):
    relative = str(path.relative_to(ROOT))
    ref = obj(relative, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=relative, sourceTree='<group>')
    app_files.append(ref)
    app_sources.append(obj(relative + ':build', 'PBXBuildFile', fileRef=ref))
for relative, file_type in [('Herbert/Assets.xcassets', 'folder.assetcatalog'), ('Herbert/PrivacyInfo.xcprivacy', 'text.xml')]:
    ref = obj(relative, 'PBXFileReference', lastKnownFileType=file_type, path=relative, sourceTree='<group>')
    app_files.append(ref)
    resources.append(obj(relative + ':build', 'PBXBuildFile', fileRef=ref))
localized_files = []
for language in ['en', 'zh-Hans', 'ja']:
    relative = f'Sources/HerbertCore/Resources/{language}.lproj/Localizable.strings'
    localized_files.append(obj(relative, 'PBXFileReference', lastKnownFileType='text.plist.strings',
                               name=language, path=relative, sourceTree='<group>'))
translations = obj('translations', 'PBXVariantGroup', children=localized_files, name='Localizable.strings', sourceTree='<group>')
app_files.append(translations)
resources.append(obj('translations:build', 'PBXBuildFile', fileRef=translations))
test_files, test_sources = [], []
for path in sorted((ROOT / 'HerbertUITests').glob('*.swift')):
    relative = str(path.relative_to(ROOT))
    ref = obj(relative, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=relative, sourceTree='<group>')
    test_files.append(ref)
    test_sources.append(obj(relative + ':build', 'PBXBuildFile', fileRef=ref))
signing = obj('signing-config', 'PBXFileReference', lastKnownFileType='text.xcconfig', path='Config/Signing.xcconfig', sourceTree='<group>')
products = obj('products', 'PBXGroup', children=[app_product, test_product, store_product, store_test_product], name='Products', sourceTree='<group>')
app_group = obj('app-group', 'PBXGroup', children=app_files, name='Herbert', sourceTree='<group>')
test_group = obj('test-group', 'PBXGroup', children=test_files, name='HerbertUITests', sourceTree='<group>')
root_group = obj('root-group', 'PBXGroup', children=[app_group, test_group, signing, products], sourceTree='<group>')


def phase(name, isa, files):
    return obj(name, isa, buildActionMask='2147483647', files=files, runOnlyForDeploymentPostprocessing='0')


common = {'SDKROOT': 'auto', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator macosx',
          'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'MACOSX_DEPLOYMENT_TARGET': '14.0',
          'TARGETED_DEVICE_FAMILY': '1,2', 'SUPPORTS_MACCATALYST': 'NO', 'SWIFT_VERSION': '6.0',
          'CLANG_ENABLE_MODULES': 'YES', 'GENERATE_INFOPLIST_FILE': 'YES',
          'CODE_SIGN_STYLE': 'Automatic', 'SWIFT_STRICT_CONCURRENCY': 'complete',
          'ENABLE_USER_SCRIPT_SANDBOXING': 'YES'}
app_settings = {**common, 'PRODUCT_BUNDLE_IDENTIFIER': 'info.hugogu.Herbert', 'PRODUCT_NAME': 'Herbert',
                'CURRENT_PROJECT_VERSION': '9', 'MARKETING_VERSION': '0.3.6',
                'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
                'INFOPLIST_KEY_CFBundleDisplayName': 'Herbert',
                'INFOPLIST_KEY_LSApplicationCategoryType': 'public.app-category.puzzle-games',
                'INFOPLIST_KEY_UIApplicationSceneManifest_Generation': 'YES',
                'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES',
                'INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents': 'YES',
                'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone': 'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
                'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad': 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
                'ENABLE_APP_SANDBOX': 'YES', 'ENABLE_USER_SELECTED_FILES': 'readwrite',
                'ENABLE_OUTGOING_NETWORK_CONNECTIONS': 'YES',
                'COMBINE_HIDPI_IMAGES': 'YES', 'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/../Frameworks', '@executable_path/Frameworks']}
test_settings = {**common, 'PRODUCT_BUNDLE_IDENTIFIER': 'info.hugogu.HerbertUITests', 'PRODUCT_NAME': '$(TARGET_NAME)',
                 'TEST_TARGET_NAME': 'Herbert', 'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@loader_path/../Frameworks', '@executable_path/../Frameworks']}


def configs(name, settings):
    result = []
    for kind in ['Debug', 'Release']:
        values = dict(settings)
        values['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if kind == 'Debug' else '-O'
        values['ONLY_ACTIVE_ARCH'] = 'YES' if kind == 'Debug' else 'NO'
        values['DEBUG_INFORMATION_FORMAT'] = 'dwarf' if kind == 'Debug' else 'dwarf-with-dsym'
        conditions = settings.get('SWIFT_ACTIVE_COMPILATION_CONDITIONS', '$(inherited)')
        if kind == 'Debug': values['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG ' + conditions
        extra = {'baseConfigurationReference': signing} if name != 'project' else {}
        result.append(obj(name + kind, 'XCBuildConfiguration', buildSettings=values, name=kind, **extra))
    return obj(name + 'configs', 'XCConfigurationList', buildConfigurations=result, defaultConfigurationIsVisible='0', defaultConfigurationName='Release')


proxy = obj('app-proxy', 'PBXContainerItemProxy', containerPortal=project_id, proxyType='1', remoteGlobalIDString=app_id, remoteInfo='Herbert')
dependency = obj('app-dependency', 'PBXTargetDependency', target=app_id, targetProxy=proxy)
obj('app', 'PBXNativeTarget', buildConfigurationList=configs('app', app_settings),
    buildPhases=[phase('app-sources', 'PBXSourcesBuildPhase', app_sources), phase('app-frameworks', 'PBXFrameworksBuildPhase', [framework, community_framework, battlefield_framework]), phase('app-resources', 'PBXResourcesBuildPhase', resources)],
    buildRules=[], dependencies=[], name='Herbert', packageProductDependencies=[product, community_product, battlefield_product], productName='Herbert', productReference=app_product, productType='com.apple.product-type.application')
obj('uitests', 'PBXNativeTarget', buildConfigurationList=configs('tests', test_settings),
    buildPhases=[phase('test-sources', 'PBXSourcesBuildPhase', test_sources), phase('test-frameworks', 'PBXFrameworksBuildPhase', [])],
    buildRules=[], dependencies=[dependency], name='HerbertUITests', productName='HerbertUITests', productReference=test_product, productType='com.apple.product-type.bundle.ui-testing')
store_settings = {**app_settings, 'PRODUCT_NAME': 'HerbertAppStore', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'APP_STORE $(inherited)'}
obj('app-store', 'PBXNativeTarget', buildConfigurationList=configs('store', store_settings),
    buildPhases=[phase('store-sources', 'PBXSourcesBuildPhase', app_sources), phase('store-frameworks', 'PBXFrameworksBuildPhase', [framework, battlefield_framework]), phase('store-resources', 'PBXResourcesBuildPhase', resources)],
    buildRules=[], dependencies=[], name='HerbertAppStore', packageProductDependencies=[product, battlefield_product], productName='HerbertAppStore', productReference=store_product, productType='com.apple.product-type.application')
store_proxy = obj('store-proxy', 'PBXContainerItemProxy', containerPortal=project_id, proxyType='1', remoteGlobalIDString=store_id, remoteInfo='HerbertAppStore')
store_dependency = obj('store-dependency', 'PBXTargetDependency', target=store_id, targetProxy=store_proxy)
store_test_settings = {**test_settings, 'PRODUCT_BUNDLE_IDENTIFIER': 'info.hugogu.HerbertAppStoreUITests',
                       'TEST_TARGET_NAME': 'HerbertAppStore', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'APP_STORE $(inherited)'}
obj('app-store-uitests', 'PBXNativeTarget', buildConfigurationList=configs('storetests', store_test_settings),
    buildPhases=[phase('store-test-sources', 'PBXSourcesBuildPhase', test_sources), phase('store-test-frameworks', 'PBXFrameworksBuildPhase', [])],
    buildRules=[], dependencies=[store_dependency], name='HerbertAppStoreUITests', productName='HerbertAppStoreUITests', productReference=store_test_product, productType='com.apple.product-type.bundle.ui-testing')
obj('project', 'PBXProject', attributes={'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '2700',
    'TargetAttributes': {app_id: {'CreatedOnToolsVersion': '27.0'}, test_id: {'CreatedOnToolsVersion': '27.0', 'TestTargetID': app_id},
                         store_id: {'CreatedOnToolsVersion': '27.0'}, store_test_id: {'CreatedOnToolsVersion': '27.0', 'TestTargetID': store_id}}},
    buildConfigurationList=configs('project', {'CLANG_WARN_DOCUMENTATION_COMMENTS': 'YES', 'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER': 'YES'}),
    compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings='0', knownRegions=['en', 'zh-Hans', 'ja', 'Base'],
    mainGroup=root_group, productRefGroup=products, projectDirPath='', projectRoot='', packageReferences=[package], targets=[app_id, test_id, store_id, store_test_id])
text = '// !$*UTF8*$!\n' + render({'archiveVersion': '1', 'classes': {}, 'objectVersion': '56', 'objects': objects, 'rootObject': project_id}) + '\n'
(PROJECT / 'project.pbxproj').write_text(text)
schemes = PROJECT / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
ref = lambda id, name: f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{id}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:Herbert.xcodeproj"/>'
def write_scheme(name, app_id, test_id, product_name, test_name):
    (schemes / f'{name}.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(app_id, product_name+'.app')}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{ref(test_id, test_name+'.xctest')}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref(test_id, test_name+'.xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app_id, product_name+'.app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app_id, product_name+'.app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
write_scheme('Herbert', app_id, test_id, 'Herbert', 'HerbertUITests')
write_scheme('HerbertAppStore', store_id, store_test_id, 'HerbertAppStore', 'HerbertAppStoreUITests')
print('Generated Herbert (community + originals) and HerbertAppStore (originals only)')
